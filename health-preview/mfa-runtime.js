import { loadRuntimeConfig, backendConfigured, assertBrowserSafeConfig } from './lib/runtime-config.js';
import { AuthController } from './lib/auth-controller.js';

const instructions=document.getElementById('instructions');
const enrollBox=document.getElementById('enroll');
const qr=document.getElementById('qr');
const secret=document.getElementById('secret');
const form=document.getElementById('mfaForm');
const code=document.getElementById('code');
const submit=document.getElementById('submit');
const status=document.getElementById('status');
let auth=null,factorId=null,challengeId=null;

function setStatus(message,error=false){
  status.textContent=message;
  status.style.background=error?'#fff0f0':'#eef8f6';
  status.style.color=error?'#8b2c2c':'#165f5a';
}

async function prepareChallenge(){
  const factors=await auth.listMfaFactors();
  const verified=(factors?.totp||[]).find(x=>x.status==='verified');

  if(verified){
    factorId=verified.id;
    instructions.textContent='Enter the six-digit code from your authenticator app.';
  }else{
    const stale=(factors?.totp||[]).filter(x=>x.status!=='verified');
    for(const factor of stale){
      try{await auth.unenrollMfa(factor.id)}catch{}
    }
    const enrolled=await auth.enrollTotp('Insurance CRM');
    factorId=enrolled?.id;
    const totp=enrolled?.totp||{};
    if(!factorId)throw new Error('Authenticator enrollment did not return a factor ID');
    enrollBox.classList.remove('hidden');
    if(totp.qr_code)qr.src=totp.qr_code;
    else qr.style.display='none';
    secret.textContent=totp.secret||'';
    instructions.textContent='Set up your authenticator app.';
  }

  const challenge=await auth.challengeTotp(factorId);
  challengeId=challenge?.id;
  if(!challengeId)throw new Error('Authenticator challenge could not be created');
  form.classList.remove('hidden');
  setStatus('Authenticator challenge ready.');
  code.focus();
}

async function initMfa(){
  const config=loadRuntimeConfig();
  assertBrowserSafeConfig(config);
  if(!backendConfigured(config)){
    setStatus('Sandbox preview: two-step verification activates when the dedicated Supabase project is connected.');
    return;
  }

  const {createClient}=await import('https://esm.sh/@supabase/supabase-js@2.116.0');
  const client=createClient(config.supabaseUrl,config.supabasePublishableKey,{
    auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}
  });
  const {data:{user}}=await client.auth.getUser();
  if(!user){location.replace('./login.html');return}

  auth=new AuthController(client);
  const aal=await auth.getAuthenticatorAssuranceLevel();
  if(aal?.currentLevel==='aal2'){
    location.replace(sessionStorage.getItem('healthMfaNext')||'./index.html');
    return;
  }

  await prepareChallenge();

  form.addEventListener('submit',async e=>{
    e.preventDefault();submit.disabled=true;
    try{
      await auth.verifyTotp(factorId,challengeId,code.value);
      const aalAfter=await auth.getAuthenticatorAssuranceLevel();
      if(aalAfter?.currentLevel!=='aal2')throw new Error('Two-step verification was not elevated to AAL2');
      setStatus('Verified. Opening your workspace…');
      const next=sessionStorage.getItem('healthMfaNext')||'./index.html';
      sessionStorage.removeItem('healthMfaNext');
      location.replace(next);
    }catch(error){
      setStatus(error?.message||'Verification failed.',true);
      code.value='';
      submit.disabled=false;
      try{
        const challenge=await auth.challengeTotp(factorId);
        challengeId=challenge?.id||challengeId;
      }catch{}
      code.focus();
    }
  });
}

initMfa().catch(error=>setStatus(error?.message||'Two-step verification initialization failed.',true));
