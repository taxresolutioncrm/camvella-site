import { createBackend } from './lib/backend-factory.js';

const backend=await createBackend();
globalThis.healthCrmBackend=backend;

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
