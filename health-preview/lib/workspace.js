export async function loadWorkspace(client){
  const {data:{user},error:userError}=await client.auth.getUser();
  if(userError)throw userError;
  if(!user)return {user:null,memberships:[],organizations:[],offices:[]};

  const {data:memberships,error:membershipError}=await client
    .from('memberships')
    .select('id,organization_id,office_id,role,is_active,created_at')
    .eq('user_id',user.id)
    .eq('is_active',true);
  if(membershipError)throw membershipError;

  const orgIds=[...new Set((memberships||[]).map(x=>x.organization_id))];
  const {data:organizations,error:orgError}=orgIds.length
    ? await client.from('organizations').select('*').in('id',orgIds)
    : {data:[],error:null};
  if(orgError)throw orgError;

  const {data:offices,error:officeError}=orgIds.length
    ? await client.from('offices').select('*').in('organization_id',orgIds)
    : {data:[],error:null};
  if(officeError)throw officeError;

  return {user,memberships:memberships||[],organizations:organizations||[],offices:offices||[]};
}

export function chooseWorkspace(workspace,preferredOrganizationId){
  const active=(workspace.memberships||[]).filter(x=>x.is_active);
  if(!active.length)return null;
  return active.find(x=>x.organization_id===preferredOrganizationId)||active[0];
}
