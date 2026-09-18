import { admin, json, corsHeaders, enforcePublicRateLimit } from '../_shared/server.ts';

Deno.serve(async(req)=>{
  if(req.method==='OPTIONS') return new Response('ok',{headers:corsHeaders(req)});
  if(req.method!=='POST') return json(req,405,{error:'method_not_allowed'});

  try{
    const allowed=await enforcePublicRateLimit(req,'public_availability',20,60);
    if(!allowed) return json(req,429,{error:'rate_limited'});
  }catch{
    return json(req,503,{error:'rate_limit_unavailable'});
  }

  try{
    const body=await req.json();
    const slug=String(body.slug||'').trim().toLowerCase().slice(0,64);
    const date=String(body.date||'').trim().slice(0,10);
    if(!slug||!/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(date)) return json(req,400,{error:'invalid_availability_request'});

    const {data,error}=await admin.rpc('get_public_availability',{p_slug:slug,p_date:date});
    if(error) return json(req,400,{error:'availability_failed',message:error.message});
    return json(req,200,{ok:true,slots:data||[]});
  }catch(error){
    return json(req,400,{error:'invalid_request',message:error instanceof Error?error.message:'invalid_request'});
  }
});
