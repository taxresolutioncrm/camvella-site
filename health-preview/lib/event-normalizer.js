export function normalizeProviderEvent(provider,event){
  const id=event.provider_event_id||event.id;
  if(!provider||!id) throw new Error('provider and provider_event_id are required');
  return {provider,provider_event_id:String(id),event_type:event.event_type||'unknown',received_at:event.received_at||new Date().toISOString(),payload_version:event.payload_version||'1',signature_valid:Boolean(event.signature_valid),raw:event};
}
export function idempotencyKey(event){return event.provider+'::'+event.provider_event_id}
