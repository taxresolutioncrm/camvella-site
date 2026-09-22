import { createBackend } from './lib/backend-factory.js';
import { ActionService } from './lib/action-service.js';
import { LiveViewService } from './lib/live-view-service.js';

async function initHealthCrmBackend(){
  const preferredOrganizationId=localStorage.getItem('health-crm-org-id')||undefined;
  const backend=await createBackend({preferredOrganizationId});
  if(backend.mode==='supabase'&&!backend.workspace?.user){
    location.replace('./login.html');
    return;
  }
  if(backend.mode==='supabase'&&backend.workspace?.user&&!backend.selected){
    const {data:portalAccounts}=await backend.client.from('client_portal_accounts')
      .select('id').eq('user_id',backend.workspace.user.id).eq('status','active').limit(1);
    location.replace(portalAccounts?.length?'./portal.html':'./onboarding.html');
    return;
  }

  if(backend.mode==='supabase'&&backend.selected){
    const sensitiveRoles=new Set(['agency_admin','manager','compliance','revenue']);
    if(sensitiveRoles.has(backend.selected.role)){
      const {data:aal,error:aalError}=await backend.client.auth.mfa.getAuthenticatorAssuranceLevel();
      if(aalError)throw aalError;
      if(aal?.currentLevel!=='aal2'){
        sessionStorage.setItem('healthMfaNext','./index.html');
        location.replace('./mfa.html');
        return;
      }
    }
  }

  globalThis.healthCrmBackend=backend;
  const actions=backend.mode==='supabase'?new ActionService(backend):null;
  const liveViews=backend.mode==='supabase'?new LiveViewService(backend):null;
  globalThis.healthCrmAction=async function(action,fields){
    if(!actions)return {sandbox:true};
    return await actions.execute(action,fields);
  };

  globalThis.healthCrmLiveRoute=async function(route){
    if(!liveViews)return null;
    return await liveViews.load(route);
  };

  globalThis.healthCrmSearch=async function(query){
    if(!query||query.trim().length<2) return [];
    if(backend.mode!=='supabase') return [];
    return await backend.repository.call('search_workspace',{p_query:query.trim(),p_limit:20});
  };

  globalThis.healthCrmStatus={
    mode:backend.mode,
    organizationId:backend.selected?.organization_id||null,
    role:backend.selected?.role||null
  };

  const signOutButton=document.getElementById('signOutBtn');
  if(signOutButton&&backend.mode==='supabase'){
    signOutButton.onclick=async()=>{
      signOutButton.disabled=true;
      try{
        await backend.client.auth.signOut();
      }finally{
        localStorage.removeItem('health-crm-org-id');
        sessionStorage.removeItem('healthMfaNext');
        location.replace('./login.html');
      }
    };
  }

  if(backend.mode==='supabase'&&backend.selected){
    localStorage.setItem('health-crm-org-id',backend.selected.organization_id);
    const select=document.getElementById('workspaceSelect');
    const nameNode=document.getElementById('accountOrgName');
    const memberships=backend.workspace?.memberships||[];
    const orgs=new Map((backend.workspace?.organizations||[]).map(o=>[o.id,o]));
    if(nameNode) nameNode.textContent=orgs.get(backend.selected.organization_id)?.name||'Agency Workspace';
    if(select&&memberships.length>1){
      select.replaceChildren();
      for(const m of memberships){
        const org=orgs.get(m.organization_id);
        const option=document.createElement('option');
        option.value=m.organization_id;
        option.textContent=(org?.name||'Agency')+' · '+m.role.replaceAll('_',' ');
        option.selected=m.organization_id===backend.selected.organization_id;
        select.append(option);
      }
      select.style.display='block';
      select.onchange=()=>{
        localStorage.setItem('health-crm-org-id',select.value);
        location.reload();
      };
    }
  }

  globalThis.dispatchEvent(new CustomEvent('health-crm-backend-ready',{detail:globalThis.healthCrmStatus}));
}

initHealthCrmBackend().catch(error=>{
  globalThis.healthCrmBackendError=error;
  globalThis.dispatchEvent(new CustomEvent('health-crm-backend-error',{detail:{message:error?.message||'backend initialization failed'}}));
});
