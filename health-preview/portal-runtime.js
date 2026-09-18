import { loadRuntimeConfig, backendConfigured, assertBrowserSafeConfig } from './lib/runtime-config.js';

const config=loadRuntimeConfig();
assertBrowserSafeConfig(config);
const content=document.getElementById('content');
const title=document.getElementById('title');
const subtitle=document.getElementById('subtitle');
const nav=[...document.querySelectorAll('.nav button')];
let client=null,portalAccount=null,clientUser=null,clientApi=null;

const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const date=v=>v?new Date(v).toLocaleDateString():'—';
const money=v=>v==null?'—':new Intl.NumberFormat('en-US',{style:'currency',currency:'USD'}).format(Number(v));

function setHeading(t,s){title.textContent=t;subtitle.textContent=s}
function empty(text){return '<div class="empty">'+esc(text)+'</div>'}
function status(message,error=false){return '<div class="status" style="'+(error?'color:#8b2c2c':'')+'">'+esc(message)+'</div>'}

async function signedDocumentUrl(doc){
  const {data,error}=await clientApi.storage.from('client-documents').createSignedUrl(doc.storage_path,300);
  if(error)throw error;
  return data.signedUrl;
}

async function loadHome(){
  setHeading('Overview','Your active coverage and recent service activity.');
  const [{data:policies,error:pErr},{data:requests,error:rErr},{data:docs,error:dErr}]=await Promise.all([
    clientApi.from('policies').select('id,policy_number,status,effective_date,renewal_date,premium_amount,carrier_id,carrier_product_id').eq('client_id',client.id).order('effective_date',{ascending:false}),
    clientApi.rpc('list_my_portal_service_requests'),
    clientApi.from('documents').select('id,document_type,file_name,created_at').eq('client_id',client.id).eq('portal_visible',true).order('created_at',{ascending:false}).limit(5)
  ]);
  if(pErr||rErr||dErr)throw pErr||rErr||dErr;
  const active=(policies||[]).filter(x=>x.status==='active');
  content.innerHTML='<div class="grid">'+
    '<div class="card"><h3>Active policies</h3><div class="metric">'+active.length+'</div><div class="muted">Coverage records currently marked active</div></div>'+
    '<div class="card"><h3>Open requests</h3><div class="metric">'+(requests||[]).filter(x=>x.status!=='resolved'&&x.status!=='closed').length+'</div><div class="muted">Service items in progress</div></div>'+
    '<div class="card"><h3>Shared documents</h3><div class="metric">'+(docs||[]).length+'</div><div class="muted">Recent files available in your portal</div></div></div>'+
    '<section class="panel"><h2>Coverage</h2><div class="muted">Your current policy records.</div><div class="list">'+((policies||[]).length?(policies||[]).map(p=>'<div class="item"><b>'+esc(p.policy_number||'Policy')+'</b><span>Effective '+date(p.effective_date)+' · Renewal '+date(p.renewal_date)+' · '+money(p.premium_amount)+'</span><div style="margin-top:7px"><span class="pill">'+esc(p.status)+'</span></div></div>').join(''):empty('No policy records are currently shared.'))+'</div></section>'+
    '<section class="panel"><h2>Recent requests</h2><div class="list">'+((requests||[]).length?(requests||[]).map(r=>'<div class="item"><b>'+esc(r.request_type)+'</b><span>'+date(r.created_at)+' · '+esc(r.priority)+'</span><div style="margin-top:7px"><span class="pill">'+esc(r.status)+'</span></div></div>').join(''):empty('No service requests yet.'))+'</div></section>';
}

async function loadDocuments(){
  setHeading('Documents','Shared files and secure uploads.');
  const {data:docs,error}=await clientApi.from('documents').select('*').eq('client_id',client.id).eq('portal_visible',true).order('created_at',{ascending:false});
  if(error)throw error;
  content.innerHTML='<section class="panel"><h2>Documents</h2><div class="muted">Only files explicitly shared with you or uploaded through this portal appear here.</div><div id="docList" class="list">'+((docs||[]).length?(docs||[]).map(d=>'<div class="item"><b>'+esc(d.file_name)+'</b><span>'+esc(d.document_type)+' · '+date(d.created_at)+'</span><button class="btn secondary openDoc" data-id="'+d.id+'" style="margin-top:9px">Open</button></div>').join(''):empty('No shared documents yet.'))+'</div></section>'+
    '<section class="panel"><h2>Upload a document</h2><form id="uploadForm" class="form"><div class="field"><label>Document type</label><input name="document_type" required maxlength="120"></div><div class="field"><label>File</label><input name="file" type="file" required></div><div class="full"><button class="btn" type="submit">Upload securely</button></div></form><div id="uploadStatus"></div></section>';
  const byId=new Map((docs||[]).map(x=>[x.id,x]));
  document.querySelectorAll('.openDoc').forEach(b=>b.onclick=async()=>{try{location.href=await signedDocumentUrl(byId.get(b.dataset.id))}catch(e){alert(e.message)}});
  document.getElementById('uploadForm').onsubmit=async e=>{
    e.preventDefault();const box=document.getElementById('uploadStatus');const fd=new FormData(e.target);const file=fd.get('file');
    if(!(file instanceof File)||!file.size){box.innerHTML=status('Choose a file.',true);return}
    if(file.size>26214400){box.innerHTML=status('Files must be 25 MB or smaller.',true);return}
    const safe=file.name.replace(/[^a-zA-Z0-9._-]+/g,'-').slice(-160);
    const path=portalAccount.organization_id+'/'+(client.office_id||'shared')+'/'+client.id+'/portal/'+crypto.randomUUID()+'-'+safe;
    box.innerHTML=status('Uploading…');
    const {error:upErr}=await clientApi.storage.from('client-documents').upload(path,file,{upsert:false,contentType:file.type||undefined});
    if(upErr){box.innerHTML=status(upErr.message,true);return}
    const {error:metaErr}=await clientApi.from('documents').insert({
      organization_id:portalAccount.organization_id,office_id:client.office_id||null,client_id:client.id,
      document_type:String(fd.get('document_type')||'portal_upload'),file_name:file.name,storage_path:path,
      mime_type:file.type||null,byte_size:file.size,uploaded_by:null,portal_visible:true
    });
    if(metaErr){await clientApi.storage.from('client-documents').remove([path]);box.innerHTML=status(metaErr.message,true);return}
    box.innerHTML=status('Upload complete.');await loadDocuments();
  };
}

async function loadRequests(){
  setHeading('Service requests','Ask your agency for help with coverage, ID cards, updates and other policy needs.');
  const {data:requests,error}=await clientApi.rpc('list_my_portal_service_requests');
  if(error)throw error;
  content.innerHTML='<section class="panel"><h2>Your requests</h2><div class="list">'+((requests||[]).length?(requests||[]).map(r=>'<div class="item"><b>'+esc(r.request_type)+'</b><span>'+date(r.created_at)+' · '+esc(r.priority)+'</span><div style="margin-top:7px"><span class="pill">'+esc(r.status)+'</span></div></div>').join(''):empty('No requests yet.'))+'</div></section>'+
  '<section class="panel"><h2>New request</h2><form id="requestForm" class="form"><div class="field"><label>Request type</label><input name="request_type" required maxlength="160"></div><div class="field"><label>Priority</label><select name="priority"><option>normal</option><option>high</option><option>urgent</option></select></div><div class="field full"><label>Details</label><textarea name="details" required maxlength="4000"></textarea></div><div class="full"><button class="btn" type="submit">Submit request</button></div></form><div id="requestStatus"></div></section>';
  document.getElementById('requestForm').onsubmit=async e=>{
    e.preventDefault();const fd=new FormData(e.target),box=document.getElementById('requestStatus');
    const requestType=String(fd.get('request_type')||'').trim();
    const details=String(fd.get('details')||'').trim();
    const {data:reqRow,error:reqErr}=await clientApi.rpc('create_my_portal_service_request',{
      p_request_type:requestType,
      p_priority:String(fd.get('priority')||'normal')
    });
    if(reqErr){box.innerHTML=status(reqErr.message,true);return}
    if(details){
      const {error:msgErr}=await clientApi.functions.invoke('send-communication',{body:{channel:'portal',to:client.id,client_id:client.id,subject:'Service request '+requestType,message:details}});
      if(msgErr)box.innerHTML=status('Request saved; message details could not be delivered.',true); else box.innerHTML=status('Request submitted.');
    }else box.innerHTML=status('Request submitted.');
    e.target.reset();await loadRequests();
  };
}

async function loadMessages(){
  setHeading('Messages','Secure messages shared between you and your agency.');
  const {data:messages,error}=await clientApi.from('portal_messages').select('id,direction,subject,body_text,created_at,read_at').eq('client_id',client.id).order('created_at',{ascending:true});
  if(error)throw error;
  const unread=(messages||[]).filter(m=>m.direction==='outbound'&&!m.read_at);
  if(unread.length)await clientApi.rpc('mark_my_portal_messages_read',{p_message_ids:unread.map(x=>x.id)});
  content.innerHTML='<section class="panel"><h2>Conversation</h2><div class="list">'+((messages||[]).length?(messages||[]).map(m=>'<div class="message '+(m.direction==='outbound'?'out':'')+'"><b>'+(m.direction==='outbound'?'Agency':'You')+' · '+date(m.created_at)+'</b><p>'+esc(m.body_text)+'</p></div>').join(''):empty('No portal messages yet.'))+'</div></section>'+
  '<section class="panel"><h2>Send a message</h2><form id="messageForm" class="form"><div class="field full"><label>Subject</label><input name="subject" maxlength="500"></div><div class="field full"><label>Message</label><textarea name="message" required maxlength="10000"></textarea></div><div class="full"><button class="btn" type="submit">Send message</button></div></form><div id="messageStatus"></div></section>';
  document.getElementById('messageForm').onsubmit=async e=>{
    e.preventDefault();const fd=new FormData(e.target),box=document.getElementById('messageStatus');
    const {data,error}=await clientApi.functions.invoke('send-communication',{body:{channel:'portal',to:client.id,client_id:client.id,subject:String(fd.get('subject')||''),message:String(fd.get('message')||'')}});
    if(error||data?.error){box.innerHTML=status(data?.message||data?.error||error?.message||'Message failed.',true);return}
    e.target.reset();box.innerHTML=status('Message sent.');await loadMessages();
  };
}

async function loadPreferences(){
  setHeading('Contact preferences','Choose which channels your agency may use to contact you.');
  const {data:pref,error}=await clientApi.from('contact_preferences').select('*').eq('client_id',client.id).maybeSingle();
  if(error)throw error;
  const p=pref||{email_allowed:true,sms_allowed:true,phone_allowed:true,fax_allowed:true,do_not_call:false};
  content.innerHTML='<section class="panel"><h2>Communication preferences</h2><form id="prefForm" class="form">'+
    ['email_allowed','sms_allowed','phone_allowed','fax_allowed'].map(k=>'<label class="item"><input type="checkbox" name="'+k+'" '+(p[k]?'checked':'')+'> '+esc(k.replace('_allowed','').toUpperCase())+' allowed</label>').join('')+
    '<label class="item"><input type="checkbox" name="do_not_call" '+(p.do_not_call?'checked':'')+'> Do not call</label>'+
    '<div class="full"><button class="btn" type="submit">Save preferences</button></div></form><div id="prefStatus"></div></section>';
  document.getElementById('prefForm').onsubmit=async e=>{
    e.preventDefault();const fd=new FormData(e.target),payload={
      organization_id:portalAccount.organization_id,client_id:client.id,lead_id:null,
      email_allowed:fd.has('email_allowed'),sms_allowed:fd.has('sms_allowed'),phone_allowed:fd.has('phone_allowed'),
      fax_allowed:fd.has('fax_allowed'),do_not_call:fd.has('do_not_call'),updated_by:null
    };
    const query=pref?clientApi.from('contact_preferences').update(payload).eq('id',pref.id):clientApi.from('contact_preferences').insert(payload);
    const {error}=await query;document.getElementById('prefStatus').innerHTML=error?status(error.message,true):status('Preferences saved.');
  };
}

const loaders={home:loadHome,documents:loadDocuments,requests:loadRequests,messages:loadMessages,preferences:loadPreferences};
async function show(view){
  nav.forEach(b=>b.classList.toggle('active',b.dataset.view===view));content.innerHTML=empty('Loading…');
  try{await (loaders[view]||loadHome)()}catch(error){content.innerHTML=empty(error?.message||'Unable to load this section.')}
}
nav.forEach(b=>b.onclick=()=>show(b.dataset.view));

async function init(){
  if(!backendConfigured(config)){content.innerHTML=empty('Client portal activates when the dedicated Supabase project is connected.');return}
  const {createClient}=await import('https://esm.sh/@supabase/supabase-js@2.116.0');
  clientApi=createClient(config.supabaseUrl,config.supabasePublishableKey,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
  const {data:{user}}=await clientApi.auth.getUser();clientUser=user;
  if(!user){sessionStorage.setItem('healthPendingInviteUrl','./portal.html');location.replace('./login.html');return}
  const {data:account,error:aErr}=await clientApi.from('client_portal_accounts').select('*').eq('user_id',user.id).eq('status','active').limit(1).maybeSingle();
  if(aErr||!account){content.innerHTML=empty('No active client portal account is linked to this login.');return}
  portalAccount=account;
  const {data:profiles,error:cErr}=await clientApi.rpc('get_my_portal_profile');
  const c=Array.isArray(profiles)?profiles[0]:profiles;
  if(cErr||!c){content.innerHTML=empty('Your client record could not be loaded.');return}
  client={...c,id:c.client_id};
  document.querySelector('.brand span').textContent=(c.first_name||'Client')+' '+(c.last_name||'');
  await show('home');
}
document.getElementById('signout').onclick=async()=>{if(clientApi)await clientApi.auth.signOut();location.replace('./login.html')};
init();
