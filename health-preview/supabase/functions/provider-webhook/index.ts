import { admin, json } from '../_shared/server.ts';

type ProviderEvent = {
  provider: string;
  provider_event_id: string;
  event_type: string;
  payload_version?: string;
  organization_id?: string | null;
  raw_payload_ref?: string | null;
};

function normalizedEnvelope(req: Request, body: Record<string,unknown>): ProviderEvent {
  const provider = String(req.headers.get('x-provider') || body.provider || '').trim();
  const provider_event_id = String(req.headers.get('x-event-id') || body.provider_event_id || body.id || '').trim();
  const event_type = String(body.event_type || body.type || 'unknown');
  if (!provider || !provider_event_id) throw new Error('provider and provider_event_id required');
  return {provider,provider_event_id,event_type,payload_version:String(body.payload_version||'1'),organization_id:null,raw_payload_ref:null};
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json(req,405,{error:'method_not_allowed'});
  try {
    const body = await req.json() as Record<string,unknown>;
    const evt = normalizedEnvelope(req,body);

    // Provider-specific signature verification MUST be added before enabling a live provider.
    // Until then, this endpoint records nothing and rejects the event.
    const verifierEnabled = false;
    if (!verifierEnabled) return json(req,503,{error:'provider_verifier_not_configured',provider:evt.provider});

    const { error } = await admin.from('provider_event_ledger').insert({
      provider:evt.provider,
      provider_event_id:evt.provider_event_id,
      event_type:evt.event_type,
      payload_version:evt.payload_version,
      signature_valid:true,
      organization_id:evt.organization_id,
      raw_payload_ref:evt.raw_payload_ref
    });
    if (error && error.code !== '23505') return json(req,500,{error:'event_persist_failed',message:error.message});
    return json(req,200,{ok:true});
  } catch (error) {
    return json(req,400,{error:'invalid_event',message:error instanceof Error ? error.message : 'invalid_event'});
  }
});
