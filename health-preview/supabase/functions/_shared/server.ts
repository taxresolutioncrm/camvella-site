export async function sha256Hex(value: string) {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return [...new Uint8Array(digest)].map(b=>b.toString(16).padStart(2,'0')).join('');
}

export async function enforcePublicRateLimit(
  admin: any,
  req: Request,
  endpoint: string,
  limit=10,
  windowSeconds=60
) {
  const salt = Deno.env.get('PUBLIC_ENDPOINT_SALT');
  if (!salt) throw new Error('PUBLIC_ENDPOINT_SALT is required');

  const forwarded = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim();
  const ip = forwarded || req.headers.get('cf-connecting-ip') || 'unknown';
  const ipHash = await sha256Hex(salt + '|' + ip);

  const { data, error } = await admin.rpc('consume_public_rate_limit', {
    p_endpoint: endpoint,
    p_ip_hash: ipHash,
    p_limit: limit,
    p_window_seconds: windowSeconds
  });
  if (error) throw error;
  return Boolean(data);
}

export function response(body: unknown,status=200){
  return Response.json(body,{status});
}

export function userIdFromClaims(claims: Record<string,unknown>|null|undefined){
  const value = claims?.sub || claims?.id;
  if(!value) throw new Error('authenticated user id missing');
  return String(value);
}

export function emailFromClaims(claims: Record<string,unknown>|null|undefined){
  const value = claims?.email;
  return value ? String(value) : null;
}


function corsHeadersFor(origin:string){
  return {
    headers:{
      'Access-Control-Allow-Origin':origin,
      'Access-Control-Allow-Headers':'authorization, apikey, content-type, x-client-info',
      'Access-Control-Allow-Methods':'POST, OPTIONS',
      'Vary':'Origin'
    }
  };
}

export function appCorsConfig(){
  return corsHeadersFor(Deno.env.get('APP_ALLOWED_ORIGIN')||'');
}

export function publicCorsConfig(){
  return corsHeadersFor(
    Deno.env.get('PUBLIC_ALLOWED_ORIGIN')
    || Deno.env.get('APP_ALLOWED_ORIGIN')
    || ''
  );
}


export function requireAal2Claims(claims: Record<string,unknown>|null|undefined){
  if(String(claims?.aal||'')!=='aal2') throw new Error('aal2_required');
  return true;
}


export function claimsHaveAal2(claims: Record<string,unknown>|null|undefined){
  return String(claims?.aal||'')==='aal2';
}
