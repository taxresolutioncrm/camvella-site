import { loadRuntimeConfig, backendConfigured, assertBrowserSafeConfig } from './lib/runtime-config.js';
import { AuthController } from './lib/auth-controller.js';

const form=document.getElementById('loginForm');
const emailInput=document.getElementById('loginEmail');
const passwordInput=document.getElementById('loginPassword');
const loginButton=document.getElementById('loginButton');
const magicButton=document.getElementById('magicButton');
const resetButton=document.getElementById('resetButton');
const status=document.getElementById('authStatus');

function setStatus(message,error=false){
  status.innerHTML=error?'<strong>Sign-in issue:</strong> '+message:message;
  status.style.background=error?'#fff0f0':'#eef8f6';
  status.style.color=error?'#8b2c2c':'#165f5a';
}
function busy(value){
  for(const b of [loginButton,magicButton,resetButton])b.disabled=value;
}
function safeReturnTarget(value){
  const raw=String(value||'').trim();
  if(!raw)return '';
  try{
    const target=new URL(raw,location.href);
    if(target.origin!==location.origin)return '';
    const allowed=['/health-preview/index.html','/health-preview/portal.html','/health-preview/accept-invite.html','/index.html','/portal.html','/accept-invite.html'];
    if(!allowed.some(path=>target.pathname.endsWith(path)))return '';
    return target.pathname+target.search+target.hash;
  }catch{return ''}
}
function pendingReturnTarget(){
  const fromUrl=safeReturnTarget(new URLSearchParams(location.search).get('return_to'));
  if(fromUrl)sessionStorage.setItem('healthPendingReturn',fromUrl);
  return fromUrl||safeReturnTarget(sessionStorage.getItem('healthPendingReturn'));
}

async function initLogin(){
  const config=loadRuntimeConfig();
  assertBrowserSafeConfig(config);

  if(!backendConfigured(config)){
    setStatus('<strong>Sandbox preview:</strong> authentication stays disconnected until the dedicated Supabase project is selected.');
    return;
  }

  const {createClient}=await import('https://esm.sh/@supabase/supabase-js@2.116.0');
  const client=createClient(config.supabaseUrl,config.supabasePublishableKey,{
    auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}
  });
  const pending=pendingReturnTarget();
  const magicUrl=new URL('./login.html',location.href);
  if(pending)magicUrl.searchParams.set('return_to',pending);
  const auth=new AuthController(client,{
    magicLinkRedirectTo:magicUrl.href,
    recoveryRedirectTo:new URL('./reset-password.html',location.href).href
  });

  const {data:{session}}=await client.auth.getSession();
  if(session){
    if(pending)sessionStorage.removeItem('healthPendingReturn');
    location.replace(pending||'./index.html');
    return;
  }

  form.addEventListener('submit',async e=>{
    e.preventDefault();busy(true);
    try{
      await auth.signInWithPassword(emailInput.value.trim(),passwordInput.value);
      setStatus('Signed in. Opening your workspace…');
      const target=pendingReturnTarget();
      if(target)sessionStorage.removeItem('healthPendingReturn');
      location.replace(target||'./index.html');
    }catch(error){
      setStatus(error?.message||'Unable to sign in.',true);
    }finally{busy(false)}
  });

  magicButton.addEventListener('click',async()=>{
    const email=emailInput.value.trim();
    if(!email){setStatus('Enter your email first.',true);return}
    busy(true);
    try{
      await auth.sendMagicLink(email);
      setStatus('Sign-in link sent. Check your email.');
    }catch(error){setStatus(error?.message||'Unable to send sign-in link.',true)}
    finally{busy(false)}
  });

  resetButton.addEventListener('click',async()=>{
    const email=emailInput.value.trim();
    if(!email){setStatus('Enter your email first.',true);return}
    busy(true);
    try{
      await auth.resetPassword(email);
      setStatus('Password reset link sent. Check your email.');
    }catch(error){setStatus(error?.message||'Unable to send reset link.',true)}
    finally{busy(false)}
  });
}

initLogin().catch(error=>setStatus(error?.message||'Authentication initialization failed.',true));
