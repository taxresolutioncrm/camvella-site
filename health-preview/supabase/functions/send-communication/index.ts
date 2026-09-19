import { withSupabase } from 'npm:@supabase/server@1.7.0';
import { response, userIdFromClaims, appCorsConfig } from '../_shared/server.ts';

const allowedChannels=new Set(['email','sms','fax','phone','portal']);
function clean(v:unknown,max=4000){return String(v??'').trim().slice(0,max)}

export default {
  fetch: withSupabase({ auth:'user', cors:appCorsConfig(), errors:{detailed:false} }, async(req,ctx)=>{
    if(req.method!=='POST') return response({error:'method_not_allowed'},405);

    try{
      const body=await req.json();
      const channel=clean(body.channel,20).toLowerCase();
      const to=clean(body.to,320);
      const subject=clean(body.subject,500);
      const message=clean(body.message,10000);
      const requestedClientId=body.client_id?clean(body.client_id,64):null;
      const requestedOrganizationId=body.organization_id?clean(body.organization_id,64):null;
      const leadId=body.lead_id?clean(body.lead_id,64):null;
      if(!allowedChannels.has(channel)||!to) return response({error:'invalid_communication_request'},400);

      const userId=userIdFromClaims(ctx.userClaims as Record<string,unknown>);
      let membershipQuery=ctx.supabase
        .from('memberships')
        .select('organization_id,office_id,role,is_active')
        .eq('user_id',userId)
        .eq('is_active',true);
      if(requestedOrganizationId) membershipQuery=membershipQuery.eq('organization_id',requestedOrganizationId);
      const {data:memberships,error:membershipError}=await membershipQuery.limit(2);

      if(membershipError) return response({error:'membership_lookup_failed'},500);
      const agencyMembership=(memberships||[]).length===1?memberships![0]:null;

      if(channel==='portal'){
        if(!message) return response({error:'portal_message_required'},400);

        let targetClient:any=null;
        let direction:'inbound'|'outbound';

        if(agencyMembership){
          if(!requestedClientId) return response({error:'portal_message_requires_client'},400);
          const {data,error}=await ctx.supabase.from('clients')
            .select('id,organization_id,office_id,assigned_user_id')
            .eq('id',requestedClientId)
            .maybeSingle();
          if(error||!data) return response({error:'client_not_accessible'},403);
          targetClient=data;
          direction='outbound';
        }else{
          let accountQuery=ctx.supabase.from('client_portal_accounts')
            .select('client_id,organization_id,status')
            .eq('user_id',userId)
            .eq('status','active');
          if(requestedClientId) accountQuery=accountQuery.eq('client_id',requestedClientId);
          const {data:portalAccount,error:portalError}=await accountQuery.maybeSingle();
          if(portalError||!portalAccount) return response({error:'portal_client_not_authorized'},403);

          const {data,error}=await ctx.supabaseAdmin.from('clients')
            .select('id,organization_id,office_id,assigned_user_id')
            .eq('id',portalAccount.client_id)
            .eq('organization_id',portalAccount.organization_id)
            .maybeSingle();
          if(error||!data) return response({error:'portal_client_not_found'},404);
          targetClient=data;
          direction='inbound';
        }

        const {data:recorded,error:recordError}=await ctx.supabaseAdmin.rpc('record_portal_message',{
          p_actor_user_id:userId,
          p_client_id:targetClient.id,
          p_direction:direction,
          p_subject:subject||null,
          p_body:message
        });
        if(recordError) return response({error:'portal_message_create_failed',message:recordError.message},400);

        return response({ok:true,...recorded});
      }

      if(!agencyMembership){
        return response({error:requestedOrganizationId?'workspace_membership_required':'workspace_context_required'},requestedOrganizationId?403:409);
      }

      let targetClient:any=null;
      let targetLead:any=null;
      if(requestedClientId){
        const {data,error}=await ctx.supabase.from('clients')
          .select('id,organization_id,office_id,assigned_user_id')
          .eq('id',requestedClientId).maybeSingle();
        if(error||!data) return response({error:'client_not_accessible'},403);
        targetClient=data;
      }
      if(leadId){
        const {data,error}=await ctx.supabase.from('leads')
          .select('id,organization_id,office_id')
          .eq('id',leadId).maybeSingle();
        if(error||!data) return response({error:'lead_not_accessible'},403);
        targetLead=data;
      }

      const organizationId=targetClient?.organization_id||targetLead?.organization_id||agencyMembership.organization_id;
      const officeId=targetClient?.office_id||targetLead?.office_id||agencyMembership.office_id||null;
      if(organizationId!==agencyMembership.organization_id) return response({error:'workspace_mismatch'},403);

      if(requestedClientId||leadId){
        let prefQuery=ctx.supabase.from('contact_preferences').select('*').eq('organization_id',organizationId);
        prefQuery=requestedClientId?prefQuery.eq('client_id',requestedClientId):prefQuery.eq('lead_id',leadId);
        const {data:pref}=await prefQuery.maybeSingle();
        if(pref){
          const denied=
            (channel==='email'&&!pref.email_allowed)||
            (channel==='sms'&&!pref.sms_allowed)||
            (channel==='phone'&&(!pref.phone_allowed||pref.do_not_call))||
            (channel==='fax'&&!pref.fax_allowed);
          if(denied) return response({error:'contact_preference_blocks_channel'},409);
        }
      }

      let endpointQuery=ctx.supabase
        .from('communication_endpoints')
        .select('id,provider_connection_id,address,status,outbound_enabled')
        .eq('organization_id',organizationId)
        .eq('channel',channel)
        .eq('status','active')
        .eq('outbound_enabled',true)
        .order('is_default',{ascending:false})
        .limit(1);
      if(officeId) endpointQuery=endpointQuery.or('office_id.is.null,office_id.eq.'+officeId);

      const {data:endpoints,error:endpointError}=await endpointQuery;
      if(endpointError) return response({error:'endpoint_lookup_failed'},500);
      const endpoint=endpoints?.[0];
      if(!endpoint?.provider_connection_id) return response({error:'communication_provider_not_connected',channel},409);

      const {data:connection,error:connectionError}=await ctx.supabaseAdmin
        .from('provider_connections')
        .select('id,organization_id,office_id,provider_name,provider_type,status,secret_ref,config_public')
        .eq('id',endpoint.provider_connection_id)
        .eq('organization_id',organizationId)
        .maybeSingle();

      if(connectionError||!connection||connection.status!=='connected'){
        return response({error:'communication_provider_not_connected',channel},409);
      }

      return response({
        error:'provider_dispatch_not_configured',
        provider:connection.provider_name,
        channel,
        endpoint:endpoint.address,
        request:{to,subject:subject||null,message_present:Boolean(message)}
      },503);
    }catch(error){
      return response({error:'invalid_request',message:error instanceof Error?error.message:'invalid_request'},400);
    }
  })
};
