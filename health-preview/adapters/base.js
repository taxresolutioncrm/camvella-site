export class AdapterError extends Error {
  constructor(code,message,details={}){super(message);this.name='AdapterError';this.code=code;this.details=details}
}
export function assertConfigured(config,required=[]){
  const missing=required.filter(k=>!config?.[k]);
  if(missing.length) throw new AdapterError('NOT_CONFIGURED','Missing adapter configuration',{missing});
}
export function normalizeStatus(value,map={}){return map[value]||String(value||'unknown').toLowerCase()}
