import { loadRuntimeConfig, backendConfigured, assertBrowserSafeConfig } from './lib/runtime-config.js';
import { AuthController } from './lib/auth-controller.js';

const form=document.getElementById('resetForm');
const password=document.getElementById('password');
const confirm=document.getElementById('confirm');
const submit=document.getElementById('submit');
const status=document.getElementById('status');

function setStatus(message,error=false){
  status.textContent=message;
  status.style.background=error?'#fff0f0':'#eef8f6';
  status.style.color=error?'#8b2c2c':'#165f5a';
}

async function initReset(){
  const config=loadRuntimeConfig();
  assertBrowserSafeConfig(config);
  if(!backendConfigured(config)){
    submit.disabled=true;
    setStatus('Sandbox preview: password recovery activates when the dedicated Supabase project is connected.');
    return;
  }

  const {createClient}=await import('https://esm.sh/@supabase/supabase-js@2.116.0');
  const client=createClient(config.supabaseUrl,config.supabasePublishableKey,{
    auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}
  });
  const auth=new AuthController(client);
  const {data:{session},error}=await client.auth.getSession();
  if(error||!session){
    submit.disabled=true;
    setStatus('This recovery session is missing or expired. Request a new reset link from the sign-in page.',true);
    return;
  }

  setStatus('Recovery session verified. Enter your new password.');

  form.addEventListener('submit',async e=>{
    e.preventDefault();
    if(password.value!==confirm.value){setStatus('Passwords do not match.',true);return}
    if(password.value.length<12){setStatus('Use at least 12 characters.',true);return}
    submit.disabled=true;
    try{
      await auth.updatePassword(password.value);
      setStatus('Password updated. Returning to sign in…');
      await auth.signOut();
      setTimeout(()=>location.replace('./login.html'),500);
    }catch(error){
      setStatus(error?.message||'Password update failed.',true);
      submit.disabled=false;
    }
  });
}

initReset().catch(error=>setStatus(error?.message||'Recovery initialization failed.',true));
