import { withSupabase } from 'npm:@supabase/server@1.7.0';
import { response, enforcePublicRateLimit, publicCorsConfig } from '../_shared/server.ts';

export default {
  fetch: withSupabase({ auth:'none', cors:publicCorsConfig(), errors:{detailed:false} }, async(req,ctx)=>{
    if(req.method!=='POST') return response({error:'method_not_allowed'},405);
    try{
      const allowed=await enforcePublicRateLimit(ctx.supabaseAdmin,req,'public_booking',5,60);
      if(!allowed) return response({error:'rate_limited'},429);

      const enabled=Deno.env.get('PUBLIC_BOOKING_ENABLED')==='true';
      if(!enabled) return response({error:'public_booking_not_enabled'},503);

      const body=await req.json();
      if(String(body.company_website||'').trim()) return response({ok:true},201);
      const slug=String(body.slug||'').trim().toLowerCase().slice(0,64);
      const startsAt=String(body.starts_at||'').trim().slice(0,64);
      const firstName=String(body.first_name||'').trim().slice(0,100);
      const lastName=String(body.last_name||'').trim().slice(0,100);
      const email=String(body.email||'').trim().slice(0,254);
      const phone=String(body.phone||'').trim().slice(0,40);
      if(!slug||!startsAt||!firstName||!lastName) return response({error:'invalid_booking_request'},400);

      const when=new Date(startsAt);
      if(Number.isNaN(when.getTime())||when.getTime()<=Date.now()) return response({error:'invalid_start_time'},400);

      const {data,error}=await ctx.supabaseAdmin.rpc('create_public_booking',{
        p_slug:slug,p_starts_at:when.toISOString(),p_first_name:firstName,p_last_name:lastName,p_email:email,p_phone:phone
      });
      if(error){
        const conflict=/no longer available|conflicts with an existing appointment|outside configured availability/i.test(error.message||'');
        return response({error:conflict?'slot_unavailable':'booking_failed',message:error.message},conflict?409:400);
      }
      return response({ok:true},201);
    }catch(error){
      return response({error:'invalid_request',message:error instanceof Error?error.message:'invalid_request'},400);
    }
  })
};
