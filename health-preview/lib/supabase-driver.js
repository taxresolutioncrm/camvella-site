const resources={
  leads:{table:'leads',key:'id',tenant:true},
  clients:{table:'clients',key:'id',tenant:true},
  households:{table:'households',key:'id',tenant:true},
  appointments:{table:'appointments',key:'id',tenant:true},
  enrollments:{table:'enrollments',key:'id',tenant:true},
  enrollmentEvidence:{table:'enrollment_evidence',key:'id',tenant:true},
  policies:{table:'policies',key:'id',tenant:true},
  policyEvents:{table:'policy_events',key:'id',tenant:true},
  serviceRequests:{table:'service_requests',key:'id',tenant:true},
  renewals:{table:'renewals',key:'id',tenant:true},
  threads:{table:'communication_threads',key:'id',tenant:true},
  communications:{table:'communications',key:'id',tenant:true},
  documents:{table:'documents',key:'id',tenant:true},
  consent:{table:'consent_records',key:'id',tenant:true},
  tasks:{table:'tasks',key:'id',tenant:true},
  carriers:{table:'carriers',key:'id',tenant:true},
  carrierProducts:{table:'carrier_products',key:'id',tenant:true},
  carrierContracts:{table:'carrier_contracts',key:'id',tenant:true},
  commissionStatements:{table:'commission_statements',key:'id',tenant:true},
  commissionLines:{table:'commission_lines',key:'id',tenant:true},
  commissionExceptions:{table:'commission_exceptions',key:'id',tenant:true},
  automationRules:{table:'automation_rules',key:'id',tenant:true},
  agentLicenses:{table:'agent_licenses',key:'id',tenant:true},
  planComparisons:{table:'plan_comparisons',key:'id',tenant:true},
  organizationSettings:{table:'organization_settings',key:'organization_id',tenant:true}
};

function spec(resource){
  const s=resources[resource];
  if(!s) throw new Error('Unknown repository resource: '+resource);
  return s;
}

export class SupabaseDriver{
  constructor(client,{organizationId}={}){
    if(!client) throw new Error('Supabase client is required');
    this.client=client;this.organizationId=organizationId||null;
  }
  withOrganization(organizationId){return new SupabaseDriver(this.client,{organizationId})}
  scope(query,s){
    if(s.tenant&&this.organizationId) return query.eq('organization_id',this.organizationId);
    return query;
  }
  async list(resource,{filters={},order='created_at',ascending=false,limit=200}={}){
    const s=spec(resource);let q=this.scope(this.client.from(s.table).select('*'),s);
    for(const [key,value] of Object.entries(filters)) if(value!==undefined) q=q.eq(key,value);
    if(order) q=q.order(order,{ascending}); if(limit) q=q.limit(limit);
    const {data,error}=await q;if(error)throw error;return data||[];
  }
  async get(resource,id){
    const s=spec(resource);let q=this.scope(this.client.from(s.table).select('*').eq(s.key,id),s);
    const {data,error}=await q.maybeSingle();if(error)throw error;return data||null;
  }
  async create(resource,payload){
    const s=spec(resource);const row={...payload};
    if(s.tenant&&this.organizationId&&!row.organization_id)row.organization_id=this.organizationId;
    const {data,error}=await this.client.from(s.table).insert(row).select().single();
    if(error)throw error;return data;
  }
  async update(resource,id,payload){
    const s=spec(resource);let q=this.client.from(s.table).update(payload).eq(s.key,id);
    q=this.scope(q,s);const {data,error}=await q.select().single();if(error)throw error;return data;
  }
  async remove(resource,id){
    const s=spec(resource);let q=this.client.from(s.table).delete().eq(s.key,id);
    q=this.scope(q,s);const {error}=await q;if(error)throw error;return true;
  }
}
