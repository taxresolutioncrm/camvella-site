import { withSupabase } from 'npm:@supabase/server@1.7.0';
import { response, userIdFromClaims, appCorsConfig, requireAal2Claims } from '../_shared/server.ts';

function parseCsv(input:string){
  const rows:string[][]=[];let row:string[]=[],cell='',quoted=false;
  for(let i=0;i<input.length;i++){
    const ch=input[i],next=input[i+1];
    if(ch==='"'&&quoted&&next==='"'){cell+='"';i++;continue}
    if(ch==='"'){quoted=!quoted;continue}
    if(ch===','&&!quoted){row.push(cell);cell='';continue}
    if((ch==='\n'||ch==='\r')&&!quoted){
      if(ch==='\r'&&next==='\n')i++;
      row.push(cell);cell='';
      if(row.some(v=>v.trim()!==''))rows.push(row);
      row=[];
      continue;
    }
    cell+=ch;
  }
  if(cell.length||row.length){row.push(cell);if(row.some(v=>v.trim()!==''))rows.push(row)}
  return rows;
}

function recordsFromCsv(input:string){
  const rows=parseCsv(input);
  if(rows.length<2)return [];
  const headers=rows[0].map(x=>x.trim().toLowerCase().replace(/[^a-z0-9]+/g,'_').replace(/^_|_$/g,''));
  return rows.slice(1).map((r,i)=>{
    const obj:Record<string,string>={__row:String(i+2)};
    headers.forEach((h,j)=>obj[h]=String(r[j]??'').trim());
    return obj;
  });
}

function marketValue(v:string){
  const x=String(v||'').trim().toLowerCase();
  return x==='aca'||x==='medicare'?x:null;
}

async function failJob(admin:any,jobId:string,organizationId:string,status:string,errorSummary:any[],rowsTotal=0,rowsValid=0,rowsFailed=0){
  await admin.from('import_jobs').update({
    status,
    rows_total:rowsTotal,
    rows_valid:rowsValid,
    rows_failed:rowsFailed,
    error_summary:errorSummary,
    finished_at:new Date().toISOString()
  }).eq('id',jobId).eq('organization_id',organizationId).eq('status','processing');
}

export default {
  fetch: withSupabase({ auth:'user', cors:appCorsConfig(), errors:{detailed:false} }, async(req,ctx)=>{
    if(req.method!=='POST')return response({error:'method_not_allowed'},405);
    try{
      requireAal2Claims(ctx.userClaims as Record<string,unknown>);
      const userId=userIdFromClaims(ctx.userClaims as Record<string,unknown>);
      const body=await req.json();
      const jobId=String(body.job_id||'');
      if(!jobId)return response({error:'job_id_required'},400);

      const {data:job,error:jobError}=await ctx.supabase
        .from('import_jobs')
        .select('*')
        .eq('id',jobId)
        .maybeSingle();

      if(jobError||!job)return response({error:'import_job_not_accessible'},403);
      if(job.created_by!==userId&&job.created_by!==null){
        const {data:adminMembership}=await ctx.supabase.from('memberships')
          .select('role').eq('organization_id',job.organization_id).eq('user_id',userId).eq('is_active',true).maybeSingle();
        if(!adminMembership||!['agency_admin','manager'].includes(adminMembership.role))return response({error:'import_job_not_owned'},403);
      }

      const {data:claimed,error:claimError}=await ctx.supabaseAdmin.from('import_jobs')
        .update({status:'processing',finished_at:null,error_summary:[]})
        .eq('id',job.id)
        .eq('organization_id',job.organization_id)
        .in('status',['uploaded','failed','validation_failed'])
        .select('id')
        .maybeSingle();
      if(claimError||!claimed)return response({error:'import_job_already_processing_or_complete'},409);

      const {data:file,error:downloadError}=await ctx.supabaseAdmin.storage.from('imports').download(job.storage_path);
      if(downloadError||!file){
        await failJob(ctx.supabaseAdmin,job.id,job.organization_id,'failed',[{row:0,errors:['import_file_download_failed']}]);
        return response({error:'import_file_download_failed'},400);
      }

      const input=await file.text();
      if(input.length>5_000_000){
        await failJob(ctx.supabaseAdmin,job.id,job.organization_id,'failed',[{row:0,errors:['import_file_too_large']}]);
        return response({error:'import_file_too_large'},413);
      }
      const rows=recordsFromCsv(input);
      if(!rows.length){
        await failJob(ctx.supabaseAdmin,job.id,job.organization_id,'failed',[{row:0,errors:['import_file_empty']}]);
        return response({error:'import_file_empty'},400);
      }
      if(rows.length>2000){
        await failJob(ctx.supabaseAdmin,job.id,job.organization_id,'failed',[{row:0,errors:['import_row_limit_exceeded']}],rows.length,0,rows.length);
        return response({error:'import_row_limit_exceeded',limit:2000},413);
      }

      const errors:Array<{row:number;errors:string[]}>=[];const valid:any[]=[];
      for(const row of rows){
        const rowErrors:string[]=[];
        if(job.import_type==='leads'||job.import_type==='clients'){
          if(!row.first_name)rowErrors.push('first_name');
          if(!row.last_name)rowErrors.push('last_name');
          if(!marketValue(row.market))rowErrors.push('market');
          if(!row.email&&!row.phone)rowErrors.push('email_or_phone');
          if(row.score&&(!Number.isFinite(Number(row.score))||Number(row.score)<0||Number(row.score)>100))rowErrors.push('score');
          if(!rowErrors.length)valid.push(row);
        }else if(job.import_type==='carrier_products'){
          if(!row.carrier)rowErrors.push('carrier');
          if(!row.product_name)rowErrors.push('product_name');
          if(!marketValue(row.market))rowErrors.push('market');
          if(!row.state)rowErrors.push('state');
          if(row.plan_year&&!Number.isFinite(Number(row.plan_year)))rowErrors.push('plan_year');
          if(!rowErrors.length)valid.push(row);
        }else{
          await failJob(ctx.supabaseAdmin,job.id,job.organization_id,'failed',[{row:0,errors:['unsupported_import_type']}],rows.length,0,rows.length);
          return response({error:'unsupported_import_type'},400);
        }
        if(rowErrors.length)errors.push({row:Number(row.__row),errors:rowErrors});
      }

      if(errors.length){
        await failJob(ctx.supabaseAdmin,job.id,job.organization_id,'validation_failed',errors.slice(0,100),rows.length,valid.length,errors.length);
        return response({ok:false,status:'validation_failed',rows_total:rows.length,rows_valid:valid.length,errors:errors.slice(0,100)},422);
      }

      await ctx.supabaseAdmin.from('import_jobs').update({
        rows_total:rows.length,rows_valid:valid.length
      }).eq('id',job.id).eq('organization_id',job.organization_id).eq('status','processing');

      let payload:any[]=[];
      if(job.import_type==='leads'){
        payload=valid.map(row=>({
          organization_id:job.organization_id,
          office_id:job.office_id,
          assigned_user_id:null,
          first_name:row.first_name,
          last_name:row.last_name,
          email:row.email||null,
          phone:row.phone||null,
          market:marketValue(row.market),
          source:row.source||'csv_import',
          stage:row.stage||'new',
          score:row.score?Number(row.score):null
        }));
      }else if(job.import_type==='clients'){
        payload=valid.map(row=>({
          organization_id:job.organization_id,
          office_id:job.office_id,
          assigned_user_id:null,
          first_name:row.first_name,
          last_name:row.last_name,
          email:row.email||null,
          phone:row.phone||null,
          market:marketValue(row.market),
          portal_status:'not_invited',
          renewal_risk:row.renewal_risk||'low'
        }));
      }else{
        const carrierNames=[...new Set(valid.map(row=>row.carrier.toLowerCase()))];
        const {data:carriers,error:carrierError}=await ctx.supabaseAdmin.from('carriers')
          .select('id,name').eq('organization_id',job.organization_id);
        if(carrierError){
          await failJob(ctx.supabaseAdmin,job.id,job.organization_id,'failed',[{row:0,errors:['carrier_lookup_failed']}],rows.length,valid.length,rows.length);
          return response({error:'carrier_lookup_failed'},500);
        }
        const carrierMap=new Map((carriers||[]).map((c:any)=>[String(c.name).toLowerCase(),c.id]));
        const missing=carrierNames.filter(n=>!carrierMap.has(n));
        if(missing.length){
          await failJob(ctx.supabaseAdmin,job.id,job.organization_id,'validation_failed',[{row:0,errors:['unknown_carriers:'+missing.join(',')]}],rows.length,0,rows.length);
          return response({error:'unknown_carriers',carriers:missing},422);
        }
        payload=valid.map(row=>({
          organization_id:job.organization_id,
          carrier_id:carrierMap.get(row.carrier.toLowerCase()),
          market:marketValue(row.market),
          product_name:row.product_name,
          product_type:row.product_type||null,
          state:row.state.toUpperCase(),
          plan_year:row.plan_year?Number(row.plan_year):null,
          external_product_id:row.external_product_id||null,
          status:row.status||'active'
        }));
      }

      const {data:applied,error:applyError}=await ctx.supabaseAdmin.rpc('apply_import_rows',{
        p_job_id:job.id,
        p_rows:payload
      });
      if(applyError){
        await failJob(ctx.supabaseAdmin,job.id,job.organization_id,'failed',[{row:2,errors:[applyError.message]}],rows.length,valid.length,payload.length);
        return response({error:'import_apply_failed',message:applyError.message},400);
      }

      return response({ok:true,status:'complete',rows_imported:applied?.rows_imported??payload.length});
    }catch(error){
      return response({error:'import_failed',message:error instanceof Error?error.message:'import_failed'},400);
    }
  })
};
