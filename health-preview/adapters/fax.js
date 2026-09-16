import {assertConfigured} from './base.js';
export class FaxAdapter {
  constructor(config={}){this.config=config}
  async send({from,to,documentRefs=[]}){assertConfigured(this.config,['provider']);return {provider:this.config.provider,status:'mock_queued',provider_message_id:'mock-fax-'+Date.now(),from,to,pages:null,document_refs:documentRefs}}
  normalizeInbound(evt){return {channel:'fax',direction:'inbound',provider:this.config.provider||'mock',provider_message_id:evt.id||evt.provider_event_id,from_address:evt.from,to_address:evt.to,fax_pages:evt.pages||null,document_ref:evt.document_ref||null,provider_status:'received'}}
}
