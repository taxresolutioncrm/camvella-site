import { loadRuntimeConfig, backendConfigured, assertBrowserSafeConfig } from './lib/runtime-config.js';

const form=document.getElementById('leadForm');
const status=document.getElementById('leadStatus');

function setStatus(message,error=false){
  status.textContent=message;
  status.style.color=error?'#8b2c2c':'#1c6f67';
}

function saveSandbox(record){
  const rows=JSON.parse(localStorage.getItem('health-crm-site-leads')||'[]');
  rows.unshift({...record,created_at:new Date().toISOString(),source:'website_preview'});
  localStorage.setItem('health-crm-site-leads',JSON.stringify(rows.slice(0,50)));
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
        setStatus('Saved in the sandbox preview.');
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
