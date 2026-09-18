import { withSupabase } from 'npm:@supabase/server@1.7.0';
import { response, userIdFromClaims, emailFromClaims } from '../_shared/server.ts';

export default {
  fetch: withSupabase({ auth:'user', errors:{detailed:false} }, async(req,ctx)=>{
    if(req.method!=='POST') return response({error:'method_not_allowed'},405);
    try{
      const body=await req.json();
      const organizationName=String(body.organization_name||'').trim();
      const officeName=String(body.office_name||'Main Office').trim();
      if(organizationName.length<2) return response({error:'organization_name_required'},400);

      const {data,error}=await ctx.supabaseAdmin.rpc('bootstrap_tenant',{
        p_user_id:userIdFromClaims(ctx.userClaims as Record<string,unknown>),
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
