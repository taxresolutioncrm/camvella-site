import { withSupabase } from 'npm:@supabase/server@1.7.0';
import { response, userIdFromClaims, appCorsConfig, claimsHaveAal2 } from '../_shared/server.ts';

export default {
  fetch: withSupabase({ auth:'user', cors:appCorsConfig(), errors:{detailed:false} }, async(req,ctx)=>{
    if(req.method!=='POST') return response({error:'method_not_allowed'},405);
    try{
      const body=await req.json();
      const clientId=String(body.client_id||'');
      const email=String(body.email||'').trim();
      if(!clientId||!email) return response({error:'client_id_and_email_required'},400);

      const actorUserId=userIdFromClaims(ctx.userClaims as Record<string,unknown>);
      const {data:client,error:clientError}=await ctx.supabase
        .from('clients')
        .select('organization_id')
        .eq('id',clientId)
        .maybeSingle();
      if(clientError||!client) return response({error:'client_not_accessible'},403);

      const {data:membership,error:membershipError}=await ctx.supabase
        .from('memberships')
        .select('role,is_active')
        .eq('organization_id',client.organization_id)
        .eq('user_id',actorUserId)
        .eq('is_active',true)
        .maybeSingle();
      if(membershipError||!membership) return response({error:'portal_invite_not_authorized'},403);
      if(['agency_admin','manager'].includes(membership.role)
         && !claimsHaveAal2(ctx.userClaims as Record<string,unknown>)){
        return response({error:'aal2_required'},403);
      }

      const {data,error}=await ctx.supabaseAdmin.rpc('create_portal_invitation',{
        p_actor_user_id:actorUserId,
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
