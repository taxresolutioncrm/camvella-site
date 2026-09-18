import { Repository, MemoryDriver } from './repository.js';
import { SupabaseDriver } from './supabase-driver.js';
import { loadRuntimeConfig, backendConfigured, assertBrowserSafeConfig } from './runtime-config.js';
import { loadWorkspace, chooseWorkspace } from './workspace.js';

export async function createBackend({seed={},preferredOrganizationId}={}){
  const config=loadRuntimeConfig();
  assertBrowserSafeConfig(config);

  if(!backendConfigured(config)){
    return {
      mode:'memory',
      config,
      client:null,
      workspace:null,
      repository:new Repository(new MemoryDriver(seed))
    };
  }

  const { createClient }=await import('https://esm.sh/@supabase/supabase-js@2.116.0');
  const client=createClient(config.supabaseUrl,config.supabasePublishableKey,{
    auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}
  });
  const workspace=await loadWorkspace(client);
  const selected=chooseWorkspace(workspace,preferredOrganizationId);
  const driver=new SupabaseDriver(client,{organizationId:selected?.organization_id||null});
  return {mode:'supabase',config,client,workspace,selected,repository:new Repository(driver)};
}
