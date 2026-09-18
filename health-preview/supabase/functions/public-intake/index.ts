import { admin, json, corsHeaders, enforcePublicRateLimit } from '../_shared/server.ts';

function clean(value:unknown,max=300){
  return String(value||'').trim().slice(0,max);
}

Deno.serve(async(req)=>{
  if(req.method==='OPTIONS') return new Response('ok',{headers:corsHeaders(req)});
  if(req.method!=='POST') return json(req,405,{error:'method_not_allowed'});

  try{
    const allowed=await enforcePublicRateLimit(req,'public_intake',5,60);
    if(!allowed) return json(req,429,{error:'rate_limited'});
  }catch(error){
    return json(req,503,{error:'rate_limit_unavailable'});
  }

  try{
    const enabled=Deno.env.get('PUBLIC_INTAKE_ENABLED')==='true';
    if(!enabled) return json(req,503,{error:'public_intake_not_enabled'});

    const body=await req.json();
    const slug=clean(body.slug,64).toLowerCase();
    const firstName=clean(body.first_name,100);
    const lastName=clean(body.last_name,100);
    const email=clean(body.email,254);
    const phone=clean(body.phone,40);
    const marketRaw=clean(body.market,20).toLowerCase();
    const market=['aca','medicare'].includes(marketRaw)?marketRaw:null;

    if(!slug||!firstName||!lastName) return json(req,400,{error:'invalid_intake'});

    // Add production rate limiting / bot protection before enabling publicly.
    const {data,error}=await admin.rpc('submit_public_intake',{
      p_slug:slug,
      p_first_name:firstName,
      p_last_name:lastName,
      p_email:email,
      p_phone:phone,
      p_market:market
    });

    if(error) return json(req,400,{error:'intake_failed',message:error.message});
    return json(req,201,{ok:true,lead_id:data.lead_id});
  }catch(error){
    return json(req,400,{error:'invalid_request',message:error instanceof Error?error.message:'invalid_request'});
  }
});
