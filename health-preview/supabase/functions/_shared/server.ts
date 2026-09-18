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
