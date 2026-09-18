import { admin, json, corsHeaders } from '../_shared/server.ts';

function clean(value:unknown,max=300){return String(value||'').trim().slice(0,max)}

Deno.serve(async(req)=>{
  if(req.method==='OPTIONS') return new Response('ok',{headers:corsHeaders(req)});
  if(req.method!=='POST') return json(req,405,{error:'method_not_allowed'});

  try{
    const enabled=Deno.env.get('PUBLIC_BOOKING_ENABLED')==='true';
    if(!enabled) return json(req,503,{error:'public_booking_not_enabled'});

    const body=await req.json();
    const slug=clean(body.slug,64).toLowerCase();
    const startsAt=clean(body.starts_at,64);
    const firstName=clean(body.first_name,100);
    const lastName=clean(body.last_name,100);
    const email=clean(body.email,254);
    const phone=clean(body.phone,40);

    if(!slug||!startsAt||!firstName||!lastName) return json(req,400,{error:'invalid_booking_request'});

    const when=new Date(startsAt);
    if(Number.isNaN(when.getTime())||when.getTime()<=Date.now()) return json(req,400,{error:'invalid_start_time'});

    // Add production rate limiting / bot protection before enabling publicly.
    const {data,error}=await admin.rpc('create_public_booking',{
      p_slug:slug,
      p_starts_at:when.toISOString(),
      p_first_name:firstName,
      p_last_name:lastName,
      p_email:email,
      p_phone:phone
    });

    if(error){
      const conflict=/no longer available/i.test(error.message||'');
      return json(req,conflict?409:400,{error:conflict?'slot_unavailable':'booking_failed',message:error.message});
    }
    return json(req,201,{ok:true,appointment_id:data.appointment_id,lead_id:data.lead_id});
  }catch(error){
    return json(req,400,{error:'invalid_request',message:error instanceof Error?error.message:'invalid_request'});
  }
});
