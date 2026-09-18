import { createClient } from 'npm:@supabase/supabase-js@2';

const url = Deno.env.get('SUPABASE_URL');
const secret = Deno.env.get('APP_SUPABASE_SECRET_KEY');

if (!url || !secret) {
  throw new Error('SUPABASE_URL and APP_SUPABASE_SECRET_KEY are required');
}

export const admin = createClient(url, secret, {
  auth: { persistSession: false, autoRefreshToken: false }
});

export function corsHeaders(req: Request) {
  const origin = req.headers.get('origin') || '';
  const allowed = (Deno.env.get('APP_ALLOWED_ORIGINS') || '').split(',').map(x=>x.trim()).filter(Boolean);
  const allow = allowed.includes(origin) ? origin : '';
  return {
    'Access-Control-Allow-Origin': allow,
    'Access-Control-Allow-Headers': 'authorization, content-type, x-client-info',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin'
  };
}

export function json(req: Request, status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(req), 'Content-Type': 'application/json' }
  });
}

export async function requireUser(req: Request) {
  const auth = req.headers.get('authorization') || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
  if (!token) throw new Error('missing bearer token');
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) throw new Error('invalid bearer token');
  return data.user;
}


export async function sha256Hex(value: string) {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return [...new Uint8Array(digest)].map(b=>b.toString(16).padStart(2,'0')).join('');
}

export async function enforcePublicRateLimit(req: Request, endpoint: string, limit=10, windowSeconds=60) {
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
