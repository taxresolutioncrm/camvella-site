import { withSupabase } from 'npm:@supabase/server@1.7.0';
import { response, enforcePublicRateLimit } from '../_shared/server.ts';

export default {
  fetch: withSupabase({ auth:'none', errors:{detailed:false} }, async(req,ctx)=>{
    if(req.method!=='POST') return response({error:'method_not_allowed'},405);
    try{
      const allowed=await enforcePublicRateLimit(ctx.supabaseAdmin,req,'public_intake',5,60);
      if(!allowed) return response({error:'rate_limited'},429);

      const enabled=Deno.env.get('PUBLIC_INTAKE_ENABLED')==='true';
      if(!enabled) return response({error:'public_intake_not_enabled'},503);

      const body=await req.json();
      const slug=String(body.slug||'').trim().toLowerCase().slice(0,64);
      const firstName=String(body.first_name||'').trim().slice(0,100);
      const lastName=String(body.last_name||'').trim().slice(0,100);
      const email=String(body.email||'').trim().slice(0,254);
      const phone=String(body.phone||'').trim().slice(0,40);
      const marketRaw=String(body.market||'').trim().toLowerCase().slice(0,20);
      const market=['aca','medicare'].includes(marketRaw)?marketRaw:null;
      if(!slug||!firstName||!lastName) return response({error:'invalid_intake'},400);

      const {data,error}=await ctx.supabaseAdmin.rpc('submit_public_intake',{
        p_slug:slug,p_first_name:firstName,p_last_name:lastName,p_email:email,p_phone:phone,p_market:market
      });
      if(error) return response({error:'intake_failed',message:error.message},400);
      return response({ok:true,lead_id:data.lead_id},201);
    }catch(error){
      return response({error:'invalid_request',message:error instanceof Error?error.message:'invalid_request'},400);
    }
  })
};
