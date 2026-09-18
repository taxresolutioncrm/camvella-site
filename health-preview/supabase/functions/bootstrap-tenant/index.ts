import { withSupabase } from 'npm:@supabase/server@1.7.0';
import { response, userIdFromClaims, emailFromClaims, appCorsConfig } from '../_shared/server.ts';

export default {
  fetch: withSupabase({ auth:'user', cors:appCorsConfig(), errors:{detailed:false} }, async(req,ctx)=>{
    if(req.method!=='POST') return response({error:'method_not_allowed'},405);
    try{
      if(Deno.env.get('TENANT_BOOTSTRAP_ENABLED')!=='true') return response({error:'tenant_bootstrap_disabled'},503);
      const userId=userIdFromClaims(ctx.userClaims as Record<string,unknown>);
      const [{data:memberships,error:membershipError},{data:portalAccounts,error:portalError}]=await Promise.all([
        ctx.supabase.from('memberships').select('id').eq('user_id',userId).eq('is_active',true).limit(1),
        ctx.supabase.from('client_portal_accounts').select('id').eq('user_id',userId).eq('status','active').limit(1)
      ]);
      if(membershipError||portalError) return response({error:'bootstrap_eligibility_check_failed'},500);
      if(memberships?.length||portalAccounts?.length) return response({error:'tenant_bootstrap_not_available_for_user'},409);

      const body=await req.json();
      const organizationName=String(body.organization_name||'').trim();
      const officeName=String(body.office_name||'Main Office').trim();
      if(organizationName.length<2) return response({error:'organization_name_required'},400);

      const {data,error}=await ctx.supabaseAdmin.rpc('bootstrap_tenant',{
        p_user_id:userId,
        p_org_name:organizationName,
        p_office_name:officeName,
        p_email:emailFromClaims(ctx.userClaims as Record<string,unknown>)
      });
      if(error) return response({error:'bootstrap_failed',message:error.message},400);
      return response({ok:true,...data});
    }catch(error){
      return response({error:'invalid_request',message:error instanceof Error?error.message:'invalid_request'},400);
    }
  })
};
