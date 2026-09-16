import {assertConfigured} from './base.js';
export class VoiceAdapter {
  constructor(config={}){this.config=config}
  async placeCall({from,to,record=true}){assertConfigured(this.config,['provider']);return {provider:this.config.provider,status:'mock_queued',provider_message_id:'mock-call-'+Date.now(),from,to,record}}
  normalizeEvent(evt){return {channel:'phone',direction:evt.direction||'inbound',provider:this.config.provider||'mock',provider_message_id:evt.id||evt.provider_event_id,from_address:evt.from,to_address:evt.to,recording_ref:evt.recording_ref||null,provider_status:evt.status||evt.event_type||'completed'}}
}
