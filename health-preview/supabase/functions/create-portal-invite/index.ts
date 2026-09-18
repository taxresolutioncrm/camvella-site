import { withSupabase } from 'npm:@supabase/server@1.7.0';
import { response, userIdFromClaims, appCorsConfig } from '../_shared/server.ts';

export default {
  fetch: withSupabase({ auth:'user', cors:appCorsConfig(), errors:{detailed:false} }, async(req,ctx)=>{
    if(req.method!=='POST') return response({error:'method_not_allowed'},405);
    try{
      const body=await req.json();
      const clientId=String(body.client_id||'');
      const email=String(body.email||'').trim();
      if(!clientId||!email) return response({error:'client_id_and_email_required'},400);

      const {data,error}=await ctx.supabaseAdmin.rpc('create_portal_invitation',{
        p_actor_user_id:userIdFromClaims(ctx.userClaims as Record<string,unknown>),
        p_client_id:clientId,
        p_email:email,
        p_hours_valid:72
      });
      if(error) return response({error:'portal_invite_create_failed',message:error.message},400);

      return response({ok:true,invitation_id:data.invitation_id,email:data.email,delivery_status:'pending_email_provider'});
    }catch(error){
      return response({error:'invalid_request',message:error instanceof Error?error.message:'invalid_request'},400);
    }
  })
};
