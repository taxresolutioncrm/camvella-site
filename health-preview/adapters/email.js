import {assertConfigured} from './base.js';
export class EmailAdapter {
  constructor(config={}){this.config=config}
  async send({to,from,subject,text,html,attachments=[]}){
    assertConfigured(this.config,['provider']);
    return {provider:this.config.provider,status:'mock_sent',provider_message_id:'mock-email-'+Date.now(),to,from,subject,attachment_count:attachments.length};
  }
  normalizeInbound(evt){return {channel:'email',direction:'inbound',provider:this.config.provider||'mock',provider_message_id:evt.id||evt.provider_event_id,from_address:evt.from,to_address:evt.to,subject:evt.subject||null,body_text:evt.text||'',provider_status:'received'}}
}
