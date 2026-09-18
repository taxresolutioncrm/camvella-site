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
      const clientId=body.client_id?clean(body.client_id,64):null;
      const leadId=body.lead_id?clean(body.lead_id,64):null;
      if(!allowedChannels.has(channel)||!to) return response({error:'invalid_communication_request'},400);

      const userId=userIdFromClaims(ctx.userClaims as Record<string,unknown>);

      let targetClient:any=null;
      let targetLead:any=null;
      if(clientId){
        const {data,error}=await ctx.supabase.from('clients')
          .select('id,organization_id,office_id,assigned_user_id')
          .eq('id',clientId).maybeSingle();
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

      if(channel==='portal'){
        if(!targetClient) return response({error:'portal_message_requires_client'},400);
        if(!message) return response({error:'portal_message_required'},400);

        const {data:portalAccount}=await ctx.supabase
          .from('client_portal_accounts')
          .select('id,status')
          .eq('client_id',targetClient.id)
          .eq('user_id',userId)
          .eq('status','active')
          .maybeSingle();

        const {data:membership}=await ctx.supabase
          .from('memberships')
          .select('organization_id,office_id,role,is_active')
          .eq('organization_id',targetClient.organization_id)
          .eq('user_id',userId)
          .eq('is_active',true)
          .maybeSingle();

        const direction=portalAccount?'inbound':'outbound';
        if(!portalAccount&&!membership) return response({error:'portal_message_not_authorized'},403);

        const {data:portalMessage,error:portalMessageError}=await ctx.supabase.from('portal_messages').insert({
          organization_id:targetClient.organization_id,
          office_id:targetClient.office_id,
          client_id:targetClient.id,
          direction,
          subject:subject||null,
          body_text:message,
          sender_user_id:userId
        }).select('id,created_at').single();

        if(portalMessageError) return response({error:'portal_message_create_failed',message:portalMessageError.message},400);

        if(direction==='inbound'){
          const now=new Date().toISOString();
          const {data:thread,error:threadError}=await ctx.supabaseAdmin.from('communication_threads').insert({
            organization_id:targetClient.organization_id,
            office_id:targetClient.office_id,
            client_id:targetClient.id,
            assigned_user_id:targetClient.assigned_user_id||null,
            subject:subject||'Portal message',
            last_channel:'portal',
            last_message_at:now,
            status:'open'
          }).select('id').single();

          if(!threadError&&thread){
            await ctx.supabaseAdmin.from('communications').insert({
              organization_id:targetClient.organization_id,
              office_id:targetClient.office_id,
              thread_id:thread.id,
              channel:'portal',
              direction:'inbound',
              client_id:targetClient.id,
              user_id:null,
              provider:'client_portal',
              provider_status:'received',
              from_address:targetClient.id,
              to_address:'agency_portal',
              subject:subject||null,
              body_text:message,
              body_preview:message.slice(0,240),
              created_at:now
            });
          }
        }

        return response({ok:true,portal_message_id:portalMessage.id,direction,created_at:portalMessage.created_at});
      }

      const {data:memberships,error:membershipError}=await ctx.supabase
        .from('memberships')
        .select('organization_id,office_id,role,is_active')
        .eq('user_id',userId)
        .eq('is_active',true)
        .limit(2);

      if(membershipError||!memberships?.length) return response({error:'workspace_membership_required'},403);
      if(memberships.length!==1) return response({error:'workspace_context_required'},409);

      const membership=memberships[0];
      const organizationId=targetClient?.organization_id||targetLead?.organization_id||membership.organization_id;
      const officeId=targetClient?.office_id||targetLead?.office_id||membership.office_id||null;
      if(organizationId!==membership.organization_id) return response({error:'workspace_mismatch'},403);

      if(clientId||leadId){
        let prefQuery=ctx.supabase.from('contact_preferences').select('*').eq('organization_id',organizationId);
        prefQuery=clientId?prefQuery.eq('client_id',clientId):prefQuery.eq('lead_id',leadId);
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
        .select('id,organization_id,office_id,provider,provider_type,status,secret_ref,settings')
        .eq('id',endpoint.provider_connection_id)
        .eq('organization_id',organizationId)
        .maybeSingle();

      if(connectionError||!connection||connection.status!=='connected'){
        return response({error:'communication_provider_not_connected',channel},409);
      }

      return response({
        error:'provider_dispatch_not_configured',
        provider:connection.provider,
        channel,
        endpoint:endpoint.address,
        request:{to,subject:subject||null,message_present:Boolean(message)}
      },503);
    }catch(error){
      return response({error:'invalid_request',message:error instanceof Error?error.message:'invalid_request'},400);
    }
  })
};
