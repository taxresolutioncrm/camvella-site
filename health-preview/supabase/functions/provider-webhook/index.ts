import { withSupabase } from 'npm:@supabase/server@1.7.0';
import { response } from '../_shared/server.ts';

function normalizedEnvelope(req:Request,body:Record<string,unknown>){
  const provider=String(req.headers.get('x-provider')||body.provider||'').trim();
  const providerEventId=String(req.headers.get('x-event-id')||body.provider_event_id||body.id||'').trim();
  const eventType=String(body.event_type||body.type||'unknown');
  if(!provider||!providerEventId) throw new Error('provider and provider_event_id required');
  return {provider,provider_event_id:providerEventId,event_type:eventType,payload_version:String(body.payload_version||'1')};
}

export default {
  fetch: withSupabase({ auth:'none', cors:'disabled', errors:{detailed:false} }, async(req,ctx)=>{
    if(req.method!=='POST') return response({error:'method_not_allowed'},405);
    try{
      const body=await req.json() as Record<string,unknown>;
      const evt=normalizedEnvelope(req,body);

      // Each live provider must supply a provider-specific signature verifier before this route is enabled.
      const verifierEnabled=false;
      if(!verifierEnabled) return response({error:'provider_verifier_not_configured',provider:evt.provider},503);

      const {error}=await ctx.supabaseAdmin.from('provider_event_ledger').insert({
        provider:evt.provider,
        provider_event_id:evt.provider_event_id,
        event_type:evt.event_type,
        payload_version:evt.payload_version,
        signature_valid:true,
        organization_id:null,
        raw_payload_ref:null
      });
      if(error&&error.code!=='23505') return response({error:'event_persist_failed',message:error.message},500);
      return response({ok:true});
    }catch(error){
      return response({error:'invalid_event',message:error instanceof Error?error.message:'invalid_event'},400);
    }
  })
};
