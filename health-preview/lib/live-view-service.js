export class LiveViewService{
  constructor(backend){this.backend=backend;this.repo=backend.repository}

  async list(resource,options={}){return await this.repo.list(resource,options)}

  async load(route){
    switch(route){
      case 'overview':{
        const [leads,enrollments,renewals,exceptions,tasks]=await Promise.all([
          this.list('leads',{limit:500}),
          this.list('enrollments',{limit:500}),
          this.list('renewals',{limit:500}),
          this.list('commissionExceptions',{limit:500}),
          this.list('tasks',{limit:500})
        ]);
        return {type:'overview',leads,enrollments,renewals,exceptions,tasks};
      }
      case 'manager':{
        const [tasks,requests,renewals,enrollments]=await Promise.all([
          this.list('tasks',{limit:500}),this.list('serviceRequests',{limit:500}),
          this.list('renewals',{limit:500}),this.list('enrollments',{limit:500})
        ]);
        return {type:'manager',tasks,requests,renewals,enrollments};
      }
      case 'reports':
      case 'advanced':{
        const [leads,appointments,enrollments,policies,renewals,statements]=await Promise.all([
          this.list('leads',{limit:1000}),this.list('appointments',{limit:1000}),
          this.list('enrollments',{limit:1000}),this.list('policies',{limit:1000}),
          this.list('renewals',{limit:1000}),this.list('commissionStatements',{limit:500})
        ]);
        return {type:'reports',leads,appointments,enrollments,policies,renewals,statements};
      }
      case 'leads': return {type:'rows',resource:'leads',rows:await this.list('leads',{limit:300})};
      case 'appointments': return {type:'rows',resource:'appointments',rows:await this.list('appointments',{order:'starts_at',ascending:true,limit:300})};
      case 'clients': return {type:'rows',resource:'clients',rows:await this.list('clients',{limit:300})};
      case 'client360':{
        const clients=await this.list('clients',{limit:1});
        const client=clients[0]||null;
        if(!client)return {type:'client360',client:null};
        const [households,policies,requests,documents]=await Promise.all([
          this.list('households',{filters:{client_id:client.id},limit:20}),
          this.list('policies',{filters:{client_id:client.id},limit:50}),
          this.list('serviceRequests',{filters:{client_id:client.id},limit:50}),
          this.list('documents',{filters:{client_id:client.id},limit:50})
        ]);
        return {type:'client360',client,households,policies,requests,documents};
      }
      case 'aca': return {type:'rows',resource:'enrollments',rows:await this.list('enrollments',{filters:{market:'aca'},limit:300})};
      case 'medicare': return {type:'rows',resource:'enrollments',rows:await this.list('enrollments',{filters:{market:'medicare'},limit:300})};
      case 'enrollment': return {type:'rows',resource:'enrollments',rows:await this.list('enrollments',{limit:300})};
      case 'eligibility': return {type:'rows',resource:'households',rows:await this.list('households',{limit:300})};
      case 'plans': return {type:'rows',resource:'planComparisons',rows:await this.list('planComparisons',{limit:300})};
      case 'evidence': return {type:'rows',resource:'evidenceBundles',rows:await this.list('evidenceBundles',{limit:300})};
      case 'policies': return {type:'rows',resource:'policies',rows:await this.list('policies',{limit:300})};
      case 'service':
      case 'requests': return {type:'rows',resource:'serviceRequests',rows:await this.list('serviceRequests',{limit:300})};
      case 'renewals': return {type:'rows',resource:'renewals',rows:await this.list('renewals',{limit:300})};
      case 'portal':{
        const [accounts,requests,messages]=await Promise.all([
          this.list('portalAccounts',{limit:300}),this.list('serviceRequests',{limit:300}),
          this.list('portalMessages',{limit:300})
        ]);
        return {type:'portal',accounts,requests,messages};
      }
      case 'commissions':{
        const [statements,lines,exceptions]=await Promise.all([
          this.list('commissionStatements',{limit:300}),this.list('commissionLines',{limit:500}),
          this.list('commissionExceptions',{limit:300})
        ]);
        return {type:'commissions',statements,lines,exceptions};
      }
      case 'exceptions': return {type:'rows',resource:'commissionExceptions',rows:await this.list('commissionExceptions',{limit:300})};
      case 'mapping': return {type:'rows',resource:'commissionLines',rows:await this.list('commissionLines',{limit:500})};
      case 'compliance':{
        const [consent,evidence,documents,audit]=await Promise.all([
          this.list('consent',{limit:300}),this.list('enrollmentEvidence',{limit:500}),
          this.list('documents',{limit:300}),this.list('auditLog',{limit:100})
        ]);
        return {type:'compliance',consent,evidence,documents,audit};
      }
      case 'consent': return {type:'rows',resource:'consent',rows:await this.list('consent',{limit:300})};
      case 'documents': return {type:'rows',resource:'documents',rows:await this.list('documents',{limit:300})};
      case 'audit': return {type:'rows',resource:'auditLog',rows:await this.list('auditLog',{limit:300})};
      case 'carriers': return {type:'rows',resource:'carriers',rows:await this.list('carriers',{limit:300})};
      case 'contracting': return {type:'rows',resource:'carrierContracts',rows:await this.list('carrierContracts',{limit:300})};
      case 'catalog': return {type:'rows',resource:'carrierProducts',rows:await this.list('carrierProducts',{limit:500})};
      case 'tasks': return {type:'rows',resource:'tasks',rows:await this.list('tasks',{limit:300})};
      case 'automations': return {type:'rows',resource:'automationRules',rows:await this.list('automationRules',{limit:300})};
      case 'team':{
        const [memberships,licenses,profiles]=await Promise.all([
          this.list('memberships',{order:'created_at',ascending:true,limit:300}),
          this.list('agentLicenses',{limit:500}),
          this.list('userProfiles',{order:'created_at',ascending:true,limit:300})
        ]);
        return {type:'team',memberships,licenses,profiles};
      }
      case 'permissions':{
        const [memberships,profiles]=await Promise.all([
          this.list('memberships',{order:'created_at',ascending:true,limit:300}),
          this.list('userProfiles',{order:'created_at',ascending:true,limit:300})
        ]);
        return {type:'permissions',memberships,profiles};
      }
      case 'inbox':
      case 'communications': return {type:'rows',resource:'communications',rows:await this.list('communications',{limit:300})};
      case 'email': return {type:'rows',resource:'communications',rows:await this.list('communications',{filters:{channel:'email'},limit:300})};
      case 'phone': return {type:'rows',resource:'communications',rows:await this.list('communications',{filters:{channel:'phone'},limit:300})};
      case 'sms': return {type:'rows',resource:'communications',rows:await this.list('communications',{filters:{channel:'sms'},limit:300})};
      case 'fax': return {type:'rows',resource:'communications',rows:await this.list('communications',{filters:{channel:'fax'},limit:300})};
      case 'voicemail': return {type:'rows',resource:'communications',rows:await this.list('communications',{filters:{channel:'voicemail'},limit:300})};
      case 'onboarding':{
        const [offices,memberships,settings]=await Promise.all([
          this.list('offices',{order:'created_at',ascending:true,limit:100}),
          this.list('memberships',{order:'created_at',ascending:true,limit:300}),
          this.list('organizationSettings',{order:null,limit:10})
        ]);
        return {type:'onboarding',offices,memberships,settings};
      }
      case 'integration':{
        const [connections,jobs,endpoints]=await Promise.all([
          this.list('providerConnections',{limit:100}),this.list('integrationSyncJobs',{limit:100}),
          this.list('communicationEndpoints',{limit:100})
        ]);
        return {type:'integration',connections,jobs,endpoints};
      }
      case 'lab':{
        const [connections,jobs,endpoints]=await Promise.all([
          this.list('providerConnections',{limit:100}),
          this.list('integrationSyncJobs',{limit:100}),
          this.list('communicationEndpoints',{limit:100})
        ]);
        return {type:'lab',connections,jobs,endpoints};
      }
      case 'settings':{
        const [settings,endpoints,types,links]=await Promise.all([
          this.list('organizationSettings',{order:null,limit:10}),
          this.list('communicationEndpoints',{limit:100}),
          this.list('appointmentTypes',{limit:100}),
          this.list('bookingLinks',{limit:100})
        ]);
        return {type:'settings',settings,endpoints,types,links};
      }
      default:return null;
    }
  }
}
