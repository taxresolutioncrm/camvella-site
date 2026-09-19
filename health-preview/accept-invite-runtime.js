import { loadRuntimeConfig, backendConfigured, assertBrowserSafeConfig } from './lib/runtime-config.js';

const config=loadRuntimeConfig();
assertBrowserSafeConfig(config);
const status=document.getElementById('status');
const retry=document.getElementById('retry');
const params=new URLSearchParams(location.search);
const type=params.get('type')||sessionStorage.getItem('healthInviteType');
const token=params.get('token')||sessionStorage.getItem('healthInviteToken');
if(params.get('token')){
  sessionStorage.setItem('healthInviteToken',params.get('token'));
  if(params.get('type'))sessionStorage.setItem('healthInviteType',params.get('type'));
  history.replaceState(null,'',location.pathname+(params.get('type')?'?type='+encodeURIComponent(params.get('type')):''));
}

function setStatus(message,error=false){
  status.textContent=message;
  status.style.background=error?'#fff0f0':'#eef8f6';
  status.style.color=error?'#8b2c2c':'#165f5a';
  retry.style.display=error?'inline-block':'none';
}
async function run(){
  if(!['team','portal'].includes(type||'')||!token){setStatus('This invitation link is incomplete.',true);return}
  if(!backendConfigured(config)){setStatus('Sandbox preview: invitation acceptance activates when the dedicated Supabase project is connected.',true);return}

  const {createClient}=await import('https://esm.sh/@supabase/supabase-js@2.116.0');
  const client=createClient(config.supabaseUrl,config.supabasePublishableKey,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
  const {data:{user}}=await client.auth.getUser();
  if(!user){
    const loginUrl=new URL('./login.html',location.href);
    loginUrl.searchParams.set('return_to',location.pathname+(type?'?type='+encodeURIComponent(type):''));
    location.replace(loginUrl.href);
    return;
  }

  setStatus('Validating invitation…');
  const functionName=type==='team'?'accept-team-invite':'accept-portal-invite';
  const {data,error}=await client.functions.invoke(functionName,{body:{token}});
  if(error){setStatus(error.message||'Invitation could not be accepted.',true);return}
  if(data?.error){setStatus(data.message||data.error,true);return}

  sessionStorage.removeItem('healthInviteToken');
  sessionStorage.removeItem('healthInviteType');
  history.replaceState(null,'',location.pathname+'?accepted=1');
  setStatus('Invitation accepted. Opening your workspace…');
  location.replace(type==='portal'?'./portal.html':'./index.html');
}
retry.addEventListener('click',run);
run();
