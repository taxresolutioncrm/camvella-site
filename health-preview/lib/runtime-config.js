export function loadRuntimeConfig(){
  const cfg=globalThis.__HEALTH_CRM_CONFIG__||{};
  return {
    supabaseUrl:String(cfg.supabaseUrl||'').trim(),
    supabasePublishableKey:String(cfg.supabasePublishableKey||'').trim(),
    environment:String(cfg.environment||'sandbox'),
    productName:String(cfg.productName||'RomyLabs Insurance CRM'),
    appOrigin:String(cfg.appOrigin||location.origin),
    publicIntakeSlug:String(cfg.publicIntakeSlug||'').trim(),
    publicBookingSlug:String(cfg.publicBookingSlug||'').trim()
  };
}

export function backendConfigured(config=loadRuntimeConfig()){
  return Boolean(config.supabaseUrl && config.supabasePublishableKey);
}

export function assertBrowserSafeConfig(config=loadRuntimeConfig()){
  for(const [key,value] of Object.entries(config)){
    const s=String(value||'').toLowerCase();
    if(key.toLowerCase().includes('secret')||s.includes('service_role')||s.startsWith('sb_secret_')){
      throw new Error('Unsafe browser configuration detected');
    }
  }
  return true;
}
