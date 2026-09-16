import {events} from './event-bus.js';
export const simulations={
  email:()=>({provider:'mock-email',event_type:'message.delivered',provider_event_id:'email-'+Date.now(),status:'delivered'}),
  sms:()=>({provider:'mock-sms',event_type:'message.received',provider_event_id:'sms-'+Date.now(),body:'I uploaded the document.',status:'received'}),
  voice:()=>({provider:'mock-voice',event_type:'call.completed',provider_event_id:'call-'+Date.now(),duration_seconds:322,status:'completed'}),
  fax:()=>({provider:'mock-fax',event_type:'fax.received',provider_event_id:'fax-'+Date.now(),pages:5,status:'received'}),
  cms:()=>({provider:'mock-cms',event_type:'plans.response',provider_event_id:'cms-'+Date.now(),plan_count:3,status:'completed'}),
  carrier:()=>({provider:'mock-carrier',event_type:'commission.statement',provider_event_id:'carrier-'+Date.now(),row_count:118,status:'received'})
};
export function runSimulation(name){if(!simulations[name])throw new Error('Unknown simulation: '+name);const event=simulations[name]();events.emit('provider.event',event);return event}
