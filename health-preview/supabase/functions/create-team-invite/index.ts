import { withSupabase } from 'npm:@supabase/server@1.7.0';
import { response, userIdFromClaims, appCorsConfig, requireAal2Claims } from '../_shared/server.ts';

export default {
  fetch: withSupabase({ auth:'user', cors:appCorsConfig(), errors:{detailed:false} }, async(req,ctx)=>{
    if(req.method!=='POST') return response({error:'method_not_allowed'},405);
    try{
      requireAal2Claims(ctx.userClaims as Record<string,unknown>);
      const body=await req.json();
      const organizationId=String(body.organization_id||'');
      const officeId=body.office_id?String(body.office_id):null;
      const email=String(body.email||'').trim();
      const role=String(body.role||'agent');
      if(!organizationId||!email) return response({error:'organization_id_and_email_required'},400);

      const {data,error}=await ctx.supabaseAdmin.rpc('create_team_invitation',{
        p_actor_user_id:userIdFromClaims(ctx.userClaims as Record<string,unknown>),
        p_organization_id:organizationId,
        p_office_id:officeId,
        p_email:email,
        p_role:role,
        p_hours_valid:72
      });
      if(error) return response({error:'invite_create_failed',message:error.message},400);

      return response({ok:true,invitation_id:data.invitation_id,email:data.email,delivery_status:'pending_email_provider'});
    }catch(error){
      return response({error:'invalid_request',message:error instanceof Error?error.message:'invalid_request'},400);
    }
  })
};
