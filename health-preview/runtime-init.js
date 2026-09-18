import { createBackend } from './lib/backend-factory.js';
import { ActionService } from './lib/action-service.js';

async function initHealthCrmBackend(){
  const backend=await createBackend();
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

  globalThis.healthCrmBackend=backend;
  const actions=backend.mode==='supabase'?new ActionService(backend):null;
  globalThis.healthCrmAction=async function(action,fields){
    if(!actions)return {sandbox:true};
    return await actions.execute(action,fields);
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

  globalThis.dispatchEvent(new CustomEvent('health-crm-backend-ready',{detail:globalThis.healthCrmStatus}));
}

initHealthCrmBackend().catch(error=>{
  globalThis.healthCrmBackendError=error;
  globalThis.dispatchEvent(new CustomEvent('health-crm-backend-error',{detail:{message:error?.message||'backend initialization failed'}}));
});
