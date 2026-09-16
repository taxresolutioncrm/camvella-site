export const featureFlags={
  livePersistence:false,
  liveEmail:false,
  liveVoice:false,
  liveSms:false,
  liveFax:false,
  liveMarketplace:false,
  liveCarrierSync:false,
  clientPortal:true,
  commissionReconciliation:true,
  complianceEvidence:true,
  integrationLab:true
};
export const isLiveIntegration=()=>Object.entries(featureFlags).filter(([k])=>k.startsWith('live')).some(([,v])=>v);
