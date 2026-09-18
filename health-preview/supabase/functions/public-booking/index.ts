import { admin, json, corsHeaders } from '../_shared/server.ts';

function clean(value:unknown,max=300){return String(value||'').trim().slice(0,max)}

Deno.serve(async(req)=>{
  if(req.method==='OPTIONS') return new Response('ok',{headers:corsHeaders(req)});
  if(req.method!=='POST') return json(req,405,{error:'method_not_allowed'});
  try{
    const body=await req.json();
    const slug=clean(body.slug,64);
    const startsAt=clean(body.starts_at,64);
    const firstName=clean(body.first_name,100);
    const lastName=clean(body.last_name,100);
    const email=clean(body.email,254);
    const phone=clean(body.phone,40);

    const publicBookingEnabled=Deno.env.get('PUBLIC_BOOKING_ENABLED')==='true';
    if(!publicBookingEnabled) return json(req,503,{error:'public_booking_not_enabled'});
    if(!slug||!startsAt||!firstName||!lastName) return json(req,400,{error:'invalid_booking_request'});

    const {data:link,error:linkError}=await admin.from('booking_links')
      .select('id,organization_id,office_id,user_id,appointment_type_id,is_active')
      .eq('slug',slug).eq('is_active',true).maybeSingle();
    if(linkError||!link) return json(req,404,{error:'booking_link_not_found'});

    const {data:type,error:typeError}=await admin.from('appointment_types')
      .select('name,market,duration_minutes,is_active')
      .eq('id',link.appointment_type_id).eq('is_active',true).single();
    if(typeError||!type) return json(req,400,{error:'appointment_type_unavailable'});

    const when=new Date(startsAt);
    if(Number.isNaN(when.getTime())||when.getTime()<=Date.now()) return json(req,400,{error:'invalid_start_time'});

    // Exact availability/race protection is verified against scheduling rules in target phase.
    const {data:lead,error:leadError}=await admin.from('leads').insert({
      organization_id:link.organization_id,
      office_id:link.office_id,
      assigned_user_id:link.user_id,
      first_name:firstName,last_name:lastName,
      email:email||null,phone:phone||null,
      market:type.market||'aca',source:'public_booking',stage:'appointment'
    }).select('id').single();
    if(leadError) return json(req,400,{error:'booking_lead_failed',message:leadError.message});

    const {data:appt,error:apptError}=await admin.from('appointments').insert({
      organization_id:link.organization_id,
      office_id:link.office_id,
      lead_id:lead.id,
      assigned_user_id:link.user_id,
      appointment_type:type.name,
      starts_at:when.toISOString(),
      duration_minutes:type.duration_minutes,
      status:'scheduled'
    }).select('id').single();
    if(apptError) return json(req,400,{error:'appointment_create_failed',message:apptError.message});

    return json(req,201,{ok:true,appointment_id:appt.id});
  }catch(error){
    return json(req,400,{error:'invalid_request',message:error instanceof Error?error.message:'invalid_request'});
  }
});
