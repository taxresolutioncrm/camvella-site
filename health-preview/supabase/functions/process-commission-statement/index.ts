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

function records(input:string){
  const rows=parseCsv(input);
  if(rows.length<2)return [];
  const headers=rows[0].map(x=>x.trim().toLowerCase().replace(/[^a-z0-9]+/g,'_').replace(/^_|_$/g,''));
  return rows.slice(1).map((r,i)=>{
    const obj:Record<string,string>={__row:String(i+2)};
    headers.forEach((h,j)=>obj[h]=String(r[j]??'').trim());
    return obj;
  });
}
function money(v:string,required=false){
  if(!v&&!required)return null;
  const n=Number(v);
  return Number.isFinite(n)?n:NaN;
}

async function markFailed(admin:any,statementId:string,reason:string){
  await admin.from('commission_statements')
    .update({import_status:'failed'})
    .eq('id',statementId);
  return reason;
}

export default {
  fetch: withSupabase({ auth:'user', cors:appCorsConfig(), errors:{detailed:false} }, async(req,ctx)=>{
    if(req.method!=='POST')return response({error:'method_not_allowed'},405);
    if(!claimsHaveAal2(ctx.userClaims as Record<string,unknown>)) return response({error:'aal2_required'},403);
    try{
      if(String((ctx.userClaims as Record<string,unknown>)?.aal||'')!=='aal2') return response({error:'aal2_required'},403);
      requireAal2Claims(ctx.userClaims as Record<string,unknown>);
      const userId=userIdFromClaims(ctx.userClaims as Record<string,unknown>);
      const body=await req.json();
      const statementId=String(body.statement_id||'');
      if(!statementId)return response({error:'statement_id_required'},400);

      const {data:statement,error:statementError}=await ctx.supabase
        .from('commission_statements')
        .select('id,organization_id,carrier_id,storage_path,import_status,source_filename')
        .eq('id',statementId).maybeSingle();
      if(statementError||!statement)return response({error:'statement_not_accessible'},403);

      const {data:membership}=await ctx.supabase
        .from('memberships')
        .select('role')
        .eq('organization_id',statement.organization_id)
        .eq('user_id',userId)
        .eq('is_active',true)
        .maybeSingle();
      if(!membership||!['agency_admin','revenue'].includes(membership.role)){
        return response({error:'commission_import_not_authorized'},403);
      }
      if(!statement.storage_path)return response({error:'statement_file_missing'},400);

      const {data:claimed,error:claimError}=await ctx.supabaseAdmin
        .from('commission_statements')
        .update({import_status:'processing'})
        .eq('id',statement.id)
        .eq('organization_id',statement.organization_id)
        .in('import_status',['uploaded','failed'])
        .select('id')
        .maybeSingle();
      if(claimError||!claimed)return response({error:'statement_already_processing_or_complete'},409);

      const {data:file,error:downloadError}=await ctx.supabaseAdmin.storage
        .from('commission-statements').download(statement.storage_path);
      if(downloadError||!file){
        await ctx.supabaseAdmin.from('commission_statements').update({import_status:'failed'}).eq('id',statement.id);
        return response({error:'statement_download_failed'},400);
      }

      const csv=await file.text();
      if(csv.length>10_000_000){await markFailed(ctx.supabaseAdmin,statement.id,'statement_file_too_large');return response({error:'statement_file_too_large'},413);}
      const rows=records(csv);
      if(!rows.length){await markFailed(ctx.supabaseAdmin,statement.id,'statement_file_empty');return response({error:'statement_file_empty'},400);}
      if(rows.length>10000){await markFailed(ctx.supabaseAdmin,statement.id,'statement_row_limit_exceeded');return response({error:'statement_row_limit_exceeded',limit:10000},413);}

      const {data:carrier,error:carrierError}=await ctx.supabaseAdmin
        .from('carriers').select('id,name').eq('id',statement.carrier_id)
        .eq('organization_id',statement.organization_id).single();
      if(carrierError||!carrier){await markFailed(ctx.supabaseAdmin,statement.id,'carrier_not_found');return response({error:'carrier_not_found'},400);}

      const errors:Array<{row:number;errors:string[]}>=[];const valid:any[]=[];
      for(const row of rows){
        const e:string[]=[];
        if(row.carrier&&row.carrier.toLowerCase()!==String(carrier.name).toLowerCase())e.push('carrier_mismatch');
        if(!row.external_policy_number)e.push('external_policy_number');
        if(!row.commission_type)e.push('commission_type');
        if(Number.isNaN(money(row.gross_amount,true)))e.push('gross_amount');
        if(Number.isNaN(money(row.net_amount,true)))e.push('net_amount');
        if(row.split_amount&&Number.isNaN(money(row.split_amount)))e.push('split_amount');
        if(e.length)errors.push({row:Number(row.__row),errors:e}); else valid.push(row);
      }
      if(errors.length){
        await ctx.supabaseAdmin.from('commission_statements').update({
          import_status:'failed',row_count:rows.length
        }).eq('id',statement.id).eq('organization_id',statement.organization_id);
        return response({error:'statement_validation_failed',errors:errors.slice(0,100)},422);
      }

      const policyNumbers=[...new Set(valid.map(r=>r.external_policy_number).filter(Boolean))];
      const {data:policies,error:policyError}=await ctx.supabaseAdmin
        .from('policies')
        .select('id,client_id,policy_number')
        .eq('organization_id',statement.organization_id)
        .eq('carrier_id',statement.carrier_id)
        .in('policy_number',policyNumbers);
      if(policyError){await markFailed(ctx.supabaseAdmin,statement.id,'policy_lookup_failed');return response({error:'policy_lookup_failed'},500);}
      const policyMap=new Map((policies||[]).map((p:any)=>[String(p.policy_number),p]));

      const producerCodes=[...new Set(valid.map(r=>r.producer_external_id).filter(Boolean))];
      let contracts:any[]=[];
      if(producerCodes.length){
        const {data,error}=await ctx.supabaseAdmin.from('carrier_contracts')
          .select('user_id,external_producer_code')
          .eq('organization_id',statement.organization_id)
          .eq('carrier_id',statement.carrier_id)
          .in('external_producer_code',producerCodes);
        if(error){await markFailed(ctx.supabaseAdmin,statement.id,'producer_lookup_failed');return response({error:'producer_lookup_failed'},500);}
        contracts=data||[];
      }
      const producerMap=new Map(contracts.map((x:any)=>[String(x.external_producer_code),x.user_id]));

      const clientIds=[...new Set((policies||[]).map((p:any)=>p.client_id).filter(Boolean))];
      let clients:any[]=[];
      if(clientIds.length){
        const {data,error}=await ctx.supabaseAdmin.from('clients')
          .select('id,assigned_user_id').eq('organization_id',statement.organization_id).in('id',clientIds);
        if(error){await markFailed(ctx.supabaseAdmin,statement.id,'client_lookup_failed');return response({error:'client_lookup_failed'},500);}
        clients=data||[];
      }
      const clientMap=new Map(clients.map((x:any)=>[x.id,x]));

      const payload=valid.map(row=>{
        const p=policyMap.get(row.external_policy_number);
        const userIdFromProducer=row.producer_external_id?producerMap.get(row.producer_external_id):null;
        const userIdFromClient=p?clientMap.get(p.client_id)?.assigned_user_id:null;
        const matchedUser=userIdFromProducer||userIdFromClient||null;
        const matched=Boolean(p&&matchedUser);
        return {
          organization_id:statement.organization_id,
          statement_id:statement.id,
          external_member_id:row.external_member_id||null,
          external_policy_number:row.external_policy_number,
          client_id:p?.client_id||null,
          policy_id:p?.id||null,
          producer_external_id:row.producer_external_id||null,
          user_id:matchedUser,
          commission_type:row.commission_type,
          gross_amount:Number(row.gross_amount),
          split_amount:row.split_amount?Number(row.split_amount):null,
          net_amount:Number(row.net_amount),
          effective_date:row.effective_date||null,
          paid_date:row.paid_date||null,
          match_status:matched?'matched':(p?'producer_unmatched':'policy_unmatched'),
          exception_reason:matched?null:(p?'Producer could not be matched':'Policy could not be matched')
        };
      });

      const normalizedRows=payload.map(row=>({
        external_member_id:row.external_member_id,
        external_policy_number:row.external_policy_number,
        client_id:row.client_id,
        policy_id:row.policy_id,
        producer_external_id:row.producer_external_id,
        user_id:row.user_id,
        commission_type:row.commission_type,
        gross_amount:row.gross_amount,
        split_amount:row.split_amount,
        net_amount:row.net_amount,
        effective_date:row.effective_date,
        paid_date:row.paid_date,
        match_status:row.match_status,
        exception_reason:row.exception_reason
      }));

      const {data:applied,error:applyError}=await ctx.supabaseAdmin.rpc('apply_commission_statement',{
        p_statement_id:statement.id,
        p_rows:normalizedRows
      });
      if(applyError){
        await markFailed(ctx.supabaseAdmin,statement.id,'commission_apply_failed');
        return response({error:'commission_apply_failed',message:applyError.message},400);
      }

      return response({
        ok:true,
        rows_imported:applied?.rows_imported??payload.length,
        exceptions:applied?.exceptions??0,
        total_amount:applied?.total_amount??0
      });
    }catch(error){
      return response({error:'commission_import_failed',message:error instanceof Error?error.message:'commission_import_failed'},400);
    }
  })
};
