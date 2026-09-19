import { loadRuntimeConfig, backendConfigured, assertBrowserSafeConfig } from './lib/runtime-config.js';

const dateInput=document.getElementById('date');
const loadButton=document.getElementById('loadSlots');
const slotsBox=document.getElementById('slots');
const slotMeta=document.getElementById('slotMeta');
const form=document.getElementById('bookingForm');
const startsAt=document.getElementById('startsAt');
const status=document.getElementById('status');
const book=document.getElementById('book');
let client=null,config=null,selectedSlot=null;

function setStatus(message,error=false){
  status.textContent=message;
  status.style.color=error?'#8b2c2c':'#1c6f67';
}
function todayLocal(){
  const d=new Date(),y=d.getFullYear(),m=String(d.getMonth()+1).padStart(2,'0'),day=String(d.getDate()).padStart(2,'0');
  return y+'-'+m+'-'+day;
}
function formatSlot(slot){
  const d=new Date(slot.starts_at);
  try{
    return new Intl.DateTimeFormat('en-US',{hour:'numeric',minute:'2-digit',timeZone:slot.timezone}).format(d);
  }catch{
    return d.toLocaleTimeString([],{hour:'numeric',minute:'2-digit'});
  }
}
async function invoke(name,body){
  const {data,error}=await client.functions.invoke(name,{body});
  if(error)throw error;
  if(data?.error)throw new Error(data.message||data.error);
  return data;
}
async function init(){
  config=loadRuntimeConfig();
  assertBrowserSafeConfig(config);
  dateInput.min=todayLocal();
  dateInput.value=todayLocal();

  const slug=new URLSearchParams(location.search).get('slug')||config.publicBookingSlug;
  if(!backendConfigured(config)||!slug){
    loadButton.disabled=true;
    setStatus('Booking activates when the dedicated Supabase project and booking link are connected.');
    return;
  }

  const {createClient}=await import('https://esm.sh/@supabase/supabase-js@2.116.0');
  client=createClient(config.supabaseUrl,config.supabasePublishableKey,{
    auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}
  });

  loadButton.addEventListener('click',async()=>{
    selectedSlot=null;startsAt.value='';form.classList.add('hidden');slotsBox.innerHTML='';slotMeta.textContent='';
    if(!dateInput.value){setStatus('Choose a date first.',true);return}
    loadButton.disabled=true;setStatus('Checking availability…');
    try{
      const result=await invoke('public-availability',{slug,date:dateInput.value});
      const slots=result.slots||[];
      if(!slots.length){setStatus('No times are available on that date.');return}
      slotMeta.textContent='Times shown in '+(slots[0].timezone||'the agency timezone')+' · '+(slots[0].duration_minutes||30)+' minutes';
      for(const slot of slots){
        const b=document.createElement('button');b.type='button';b.className='slot';b.textContent=formatSlot(slot);
        b.onclick=()=>{
          [...slotsBox.children].forEach(x=>x.classList.remove('selected'));b.classList.add('selected');
          selectedSlot=slot;startsAt.value=slot.starts_at;form.classList.remove('hidden');
          setStatus('Time selected. Enter your contact details to finish booking.');
        };
        slotsBox.appendChild(b);
      }
      setStatus('Choose an available time.');
    }catch(error){
      setStatus(error?.message||'Unable to load availability.',true);
    }finally{loadButton.disabled=false}
  });

  form.addEventListener('submit',async e=>{
    e.preventDefault();
    if(!selectedSlot){setStatus('Choose an available time first.',true);return}
    book.disabled=true;setStatus('Booking your appointment…');
    try{
      const body={slug,...Object.fromEntries(new FormData(form))};
      if(String(body.company_website||'').trim()){
        setStatus('Appointment request received.');form.reset();form.classList.add('hidden');selectedSlot=null;return;
      }
      const result=await invoke('public-booking',body);
      setStatus('Appointment booked. Your request is saved with the agency.');
      slotsBox.innerHTML='';slotMeta.textContent='';form.reset();form.classList.add('hidden');selectedSlot=null;
    }catch(error){
      setStatus(error?.message||'Unable to book that time. Refresh availability and try again.',true);
    }finally{book.disabled=false}
  });
}
init().catch(error=>setStatus(error?.message||'Booking initialization failed.',true));
