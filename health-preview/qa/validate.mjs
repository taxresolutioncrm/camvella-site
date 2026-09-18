import fs from 'node:fs';
import path from 'node:path';

const root=path.resolve(process.cwd(),'health-preview');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const exists=p=>fs.existsSync(path.join(root,p));
const failures=[];

const app=read('index.html');
const site=read('site.html');
const login=read('login.html');
const portal=read('portal.html');
const onboarding=read('onboarding.html');
const acceptInvite=read('accept-invite.html');
const resetPassword=read('reset-password.html');
const mfa=read('mfa.html');

const migrationDir=path.join(root,'supabase','migrations');
const names=fs.readdirSync(migrationDir).filter(x=>/^\d+_.*\.sql$/.test(x)).sort();
const mig=Object.fromEntries(names.map(f=>[f,read('supabase/migrations/'+f)]));
const allMig=Object.values(mig).join('\n');

for(const fn of ['email','phone','sms','fax','voicemail','inbox','integration','lab']){
  if(!app.includes('function '+fn+'()')) failures.push('missing CRM view '+fn);
}
if(!app.includes('groupToggle')||!app.includes('health-crm-sidebar-groups-v1')) failures.push('collapsible sidebar missing');
if(!app.includes('actionModal')||!app.includes('health-crm-sandbox-actions')) failures.push('interactive sandbox actions missing');
if(!app.includes('./runtime-init.js')) failures.push('runtime backend bridge missing');
if(!app.includes('const routeRoles=')||!app.includes('function applyRoleUi')) failures.push('role-aware CRM UI missing');
if(!read('runtime-init.js').includes('ActionService')) failures.push('live action service bridge missing');
if(!exists('portal-runtime.js')) failures.push('client portal runtime missing');
if(!exists('login-runtime.js')) failures.push('login runtime missing');
if(!exists('onboarding-runtime.js')) failures.push('onboarding runtime missing');
if(!exists('accept-invite-runtime.js')) failures.push('invite acceptance runtime missing');
if(!exists('reset-password-runtime.js')) failures.push('password reset runtime missing');
if(!exists('mfa-runtime.js')) failures.push('MFA runtime missing');

for(const surface of [['site',site],['login',login],['portal',portal],['onboarding',onboarding],['accept-invite',acceptInvite],['reset-password',resetPassword],['mfa',mfa]]){
  if(!surface[1].includes('noindex,nofollow')) failures.push(surface[0]+' preview surface must remain noindex');
}

const forbiddenFrontend=['service_role','sb_secret_','APP_SUPABASE_SECRET_KEY='];
for(const secret of forbiddenFrontend){
  for(const [name,source] of [['app',app],['login',login],['portal',portal],['onboarding',onboarding],['invite',acceptInvite],['reset-password',resetPassword],['mfa',mfa]]){
    if(source.includes(secret)) failures.push(name+' frontend secret marker '+secret);
  }
}

const tables=[...new Set([...allMig.matchAll(/create table public\.([a-z0-9_]+)/g)].map(m=>m[1]))];
const rlsEnabled=new Set([...allMig.matchAll(/alter table public\.([a-z0-9_]+) enable row level security/g)].map(m=>m[1]));
for(const t of tables) if(!rlsEnabled.has(t)) failures.push('RLS enable missing '+t);

for(const p of [...allMig.matchAll(/create policy [\s\S]*? for update to authenticated[\s\S]*?;/g)].map(m=>m[0])){
  if(!p.toLowerCase().includes('with check')) failures.push('update policy missing WITH CHECK');
}

for(const v of [...allMig.matchAll(/create view public\.([a-z0-9_]+)[\s\S]*?;/g)].map(m=>m[0])){
  if(!v.includes('security_invoker = true')) failures.push('security_invoker missing view');
}

const securityDefiners=[...allMig.matchAll(/create or replace function[\s\S]*?\$\$;/gi)].map(m=>m[0]).filter(x=>/security definer/i.test(x));
for(const fn of securityDefiners){
  if(!/set search_path\s*=/i.test(fn)) failures.push('SECURITY DEFINER function missing fixed search_path');
}

const storageFiles=['004_storage.sql','017_security_cleanup_and_audit.sql','024_storage_role_alignment.sql','028_portal_privacy_and_task_roles.sql','040_import_storage.sql','046_import_storage_role_alignment.sql','047_portal_data_boundary.sql'];
const storage=storageFiles.filter(x=>mig[x]).map(x=>mig[x]).join('\n');
for(const op of ['select','insert','update','delete']){
  if(!storage.includes('for '+op+' to authenticated')) failures.push('storage policy missing '+op);
}
if(!storage.includes("visibility not in ('portal','shared')")) failures.push('portal storage visibility boundary missing');

if(!mig['007_data_api_grants.sql']?.includes('revoke all on all tables in schema public from anon')) failures.push('anon table revoke missing');
if(!mig['007_data_api_grants.sql']?.includes('revoke all on tables from anon, authenticated')) failures.push('future table opt-in missing');

for(const required of [
  '022_role_policy_alignment.sql','023_function_privilege_lockdown.sql','024_storage_role_alignment.sql',
  '028_portal_privacy_and_task_roles.sql','029_scheduling_and_invite_integrity.sql',
  '030_actor_and_attachment_integrity.sql','033_active_assignment_guard.sql',
  '034_portal_account_visibility.sql','035_membership_write_hardening.sql',
  '037_assignment_office_alignment.sql','038_atomic_enrollment_case.sql',
  '039_workflow_artifacts_and_imports.sql','041_policy_event_and_campaign_role_alignment.sql',
  '042_import_job_role_alignment.sql','044_atomic_import_apply.sql','045_atomic_commission_apply.sql',
  '047_portal_data_boundary.sql','048_portal_messages.sql','049_portal_message_sender_guard.sql',
  '050_portal_least_privilege.sql','051_portal_message_read_receipts.sql','052_aal2_sensitive_writes.sql'
]){
  if(!mig[required]) failures.push('missing hardening module '+required);
}

if(!read('lib/auth-controller.js').includes('enrollTotp')) failures.push('MFA auth controller missing');
if(!read('runtime-init.js').includes("sensitiveRoles")) failures.push('sensitive-role AAL2 runtime gate missing');
if(!allMig.includes('app_private.has_aal2()')) failures.push('database AAL2 sensitive-write guard missing');
if(!read('lib/supabase-driver.js').includes('class SupabaseDriver')) failures.push('Supabase driver missing');
if(!read('lib/backend-factory.js').includes('@supabase/supabase-js@2.116.0')) failures.push('pinned browser Supabase SDK missing');
if(!read('lib/action-service.js').includes('class ActionService')) failures.push('live CRM action service missing');

const edgeFiles=[
  'bootstrap-tenant','accept-team-invite','create-team-invite','create-portal-invite','accept-portal-invite',
  'public-intake','public-booking','public-availability','provider-webhook',
  'send-communication','process-import','process-commission-statement'
];
for(const fn of edgeFiles){
  const p='supabase/functions/'+fn+'/index.ts';
  if(!exists(p)){failures.push('missing Edge Function '+fn);continue}
  const source=read(p);
  if(!source.includes("@supabase/server@1.7.0")) failures.push('unpinned Edge SDK '+fn);
}

const config=read('supabase/config.toml');
for(const fn of ['provider-webhook','public-intake','public-booking','public-availability']){
  if(!config.includes('[functions.'+fn+']')) failures.push('missing function config '+fn);
}
if((config.match(/verify_jwt = false/g)||[]).length!==4) failures.push('unexpected verify_jwt=false function count');

if(!site.includes('SoftwareApplication')) failures.push('website SoftwareApplication schema missing');
if(!site.includes('leadForm')) failures.push('website lead capture missing');
if(!portal.includes('Documents')||!portal.includes('Requests')||!portal.includes('Messages')) failures.push('portal navigation incomplete');

const actionLabels=[...new Set([...app.matchAll(/btn\('([^']+)'/g)].map(m=>m[1]))];
const actionSchemas=[...app.matchAll(/^'([^']+)':\[\[/gm)].map(m=>m[1]);
const commandMatch=(app.match(/const commandLabels=\[([^\]]+)\]/)||[])[1]||'';
const commands=[...commandMatch.matchAll(/'([^']+)'/g)].map(m=>m[1]);
const actionService=read('lib/action-service.js');
for(const label of actionLabels){
  const covered=
    actionSchemas.some(k=>label.toLowerCase().includes(k.toLowerCase()))||
    commands.some(k=>label.includes(k))||
    /^Export/.test(label)||
    actionService.includes("'"+label+"'")||
    actionService.includes("includes('"+label+"')");
  if(!covered) failures.push('uncovered CRM action '+label);
}

if(tables.length<58) failures.push('expected at least 58 public tables, found '+tables.length);
if(names.length<52) failures.push('expected at least 52 SQL modules, found '+names.length);

console.log(JSON.stringify({
  tables:tables.length,
  sqlModules:names.length,
  edgeFunctions:edgeFiles.length,
  crmActions:actionLabels.length,
  failures
},null,2));

if(failures.length) process.exit(1);
