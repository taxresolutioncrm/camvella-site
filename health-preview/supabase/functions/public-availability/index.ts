import { withSupabase } from 'npm:@supabase/server@1.7.0';
import { response, enforcePublicRateLimit } from '../_shared/server.ts';

export default {
  fetch: withSupabase({ auth:'none', errors:{detailed:false} }, async(req,ctx)=>{
    if(req.method!=='POST') return response({error:'method_not_allowed'},405);
    try{
      const allowed=await enforcePublicRateLimit(ctx.supabaseAdmin,req,'public_availability',20,60);
      if(!allowed) return response({error:'rate_limited'},429);

      const body=await req.json();
      const slug=String(body.slug||'').trim().toLowerCase().slice(0,64);
      const date=String(body.date||'').trim().slice(0,10);
      if(!slug||!/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(date)) return response({error:'invalid_availability_request'},400);

      const {data,error}=await ctx.supabaseAdmin.rpc('get_public_availability',{p_slug:slug,p_date:date});
      if(error) return response({error:'availability_failed',message:error.message},400);
      return response({ok:true,slots:data||[]});
    }catch(error){
      return response({error:'invalid_request',message:error instanceof Error?error.message:'invalid_request'},400);
    }
  })
};
