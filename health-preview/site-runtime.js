import { loadRuntimeConfig, backendConfigured, assertBrowserSafeConfig } from './lib/runtime-config.js';

const form=document.getElementById('leadForm');
const status=document.getElementById('leadStatus');

function setStatus(message,error=false){
  status.textContent=message;
  status.style.color=error?'#8b2c2c':'#1c6f67';
}

function saveSandbox(){
  // Preview mode intentionally does not persist public contact information.
  return true;
}

async function init(){
  const config=loadRuntimeConfig();
  assertBrowserSafeConfig(config);

  form.addEventListener('submit',async e=>{
    e.preventDefault();
    const submit=form.querySelector('button[type="submit"]');
    submit.disabled=true;
    const body=Object.fromEntries(new FormData(form));
    if(String(body.company_website||'').trim()){
      setStatus('Thank you — your request was received.');
      form.reset();submit.disabled=false;return;
    }

    try{
      if(!backendConfigured(config)||!config.publicIntakeSlug){
        saveSandbox(body);
        setStatus('Preview only — no contact information was stored or submitted.');
        form.reset();
        return;
      }

      const {createClient}=await import('https://esm.sh/@supabase/supabase-js@2.116.0');
      const client=createClient(config.supabaseUrl,config.supabasePublishableKey,{
        auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}
      });
      const {data,error}=await client.functions.invoke('public-intake',{
        body:{slug:config.publicIntakeSlug,...body}
      });
      if(error)throw error;
      if(data?.error)throw new Error(data.message||data.error);

      setStatus('Thank you — your request was received.');
      form.reset();
    }catch(error){
      setStatus(error?.message||'Unable to submit your request right now.',true);
    }finally{
      submit.disabled=false;
    }
  });
}

init().catch(error=>setStatus(error?.message||'Lead form initialization failed.',true));
