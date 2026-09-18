import { admin, json, corsHeaders } from '../_shared/server.ts';

function clean(value:unknown,max=300){
  return String(value||'').trim().slice(0,max);
}

Deno.serve(async(req)=>{
  if(req.method==='OPTIONS') return new Response('ok',{headers:corsHeaders(req)});
  if(req.method!=='POST') return json(req,405,{error:'method_not_allowed'});
  try{
    const body=await req.json();
    const organizationId=clean(body.organization_id,64);
    const officeId=body.office_id?clean(body.office_id,64):null;
    const firstName=clean(body.first_name,100);
    const lastName=clean(body.last_name,100);
    const email=clean(body.email,254);
    const phone=clean(body.phone,40);
    const market=clean(body.market,20).toLowerCase();
    const source=clean(body.source||'website',100);

    if(!organizationId||!firstName||!lastName||!['aca','medicare'].includes(market)){
      return json(req,400,{error:'invalid_intake'});
    }

    // Enable rate-limit / bot-verification provider before production.
    const publicIntakeEnabled=Deno.env.get('PUBLIC_INTAKE_ENABLED')==='true';
    if(!publicIntakeEnabled) return json(req,503,{error:'public_intake_not_enabled'});

    const {data,error}=await admin.from('leads').insert({
      organization_id:organizationId,
      office_id:officeId,
      first_name:firstName,
      last_name:lastName,
      email:email||null,
      phone:phone||null,
      market,
      source,
      stage:'new'
    }).select('id').single();

    if(error) return json(req,400,{error:'lead_create_failed',message:error.message});
    return json(req,201,{ok:true,lead_id:data.id});
  }catch(error){
    return json(req,400,{error:'invalid_request',message:error instanceof Error?error.message:'invalid_request'});
  }
});
