import { withSupabase } from 'npm:@supabase/server@1.7.0';
import { response, userIdFromClaims, emailFromClaims, appCorsConfig } from '../_shared/server.ts';

export default {
  fetch: withSupabase({ auth:'user', cors:appCorsConfig(), errors:{detailed:false} }, async(req,ctx)=>{
    if(req.method!=='POST') return response({error:'method_not_allowed'},405);
    try{
      const body=await req.json();
      const token=String(body.token||'');
      const email=emailFromClaims(ctx.userClaims as Record<string,unknown>);
      if(!token||!email) return response({error:'token_and_email_required'},400);

      const {data,error}=await ctx.supabaseAdmin.rpc('accept_team_invite',{
        p_user_id:userIdFromClaims(ctx.userClaims as Record<string,unknown>),
        p_email:email,
        p_token:token
      });
      if(error) return response({error:'invite_accept_failed',message:error.message},400);
      return response({ok:true,...data});
    }catch(error){
      return response({error:'invalid_request',message:error instanceof Error?error.message:'invalid_request'},400);
    }
  })
};
