import {assertConfigured} from './base.js';
export class SmsAdapter {
  constructor(config={}){this.config=config}
  async send({from,to,text}){assertConfigured(this.config,['provider']);return {provider:this.config.provider,status:'mock_sent',provider_message_id:'mock-sms-'+Date.now(),from,to,text}}
  normalizeInbound(evt){return {channel:'sms',direction:'inbound',provider:this.config.provider||'mock',provider_message_id:evt.id||evt.provider_event_id,from_address:evt.from,to_address:evt.to,body_text:evt.body||evt.text||'',provider_status:'received'}}
}
