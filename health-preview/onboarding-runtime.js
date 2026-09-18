import { loadRuntimeConfig, backendConfigured, assertBrowserSafeConfig } from './lib/runtime-config.js';

const form=document.getElementById('form');
const submit=document.getElementById('submit');
const status=document.getElementById('status');

function setStatus(message,error=false){
  status.textContent=message;
  status.style.background=error?'#fff0f0':'#eef8f6';
  status.style.color=error?'#8b2c2c':'#165f5a';
}

async function initOnboarding(){
  const config=loadRuntimeConfig();
  assertBrowserSafeConfig(config);

  if(!backendConfigured(config)){
    setStatus('Sandbox preview: onboarding connects when the dedicated Supabase project is selected.');
    submit.disabled=true;
    return;
  }

  const {createClient}=await import('https://esm.sh/@supabase/supabase-js@2.116.0');
  const client=createClient(config.supabaseUrl,config.supabasePublishableKey,{
    auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}
  });
  const {data:{user}}=await client.auth.getUser();
  if(!user){location.replace('./login.html');return}

  const {data:memberships,error}=await client.from('memberships')
    .select('id').eq('user_id',user.id).eq('is_active',true).limit(1);
  if(error){setStatus(error.message,true);return}
  if(memberships?.length){location.replace('./index.html');return}

  setStatus('Signed in. Create your agency workspace.');

  form.addEventListener('submit',async e=>{
    e.preventDefault();submit.disabled=true;
    try{
      const body=Object.fromEntries(new FormData(form));
      const {data,error}=await client.functions.invoke('bootstrap-tenant',{body});
      if(error)throw error;
      if(data?.error)throw new Error(data.message||data.error);
      setStatus('Workspace created. Opening the CRM…');
      location.replace('./index.html');
    }catch(error){
      setStatus(error?.message||'Workspace creation failed.',true);
      submit.disabled=false;
    }
  });
}

initOnboarding().catch(error=>setStatus(error?.message||'Onboarding initialization failed.',true));
