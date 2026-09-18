import { admin, json, requireUser, corsHeaders } from '../_shared/server.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(req) });
  if (req.method !== 'POST') return json(req,405,{error:'method_not_allowed'});
  try {
    const user = await requireUser(req);
    const body = await req.json();
    const token = String(body.token || '');
    if (!token || !user.email) return json(req,400,{error:'token_and_email_required'});

    const { data, error } = await admin.rpc('accept_team_invite',{
      p_user_id:user.id,
      p_email:user.email,
      p_token:token
    });
    if (error) return json(req,400,{error:'invite_accept_failed',message:error.message});
    return json(req,200,{ok:true,...data});
  } catch (error) {
    return json(req,401,{error:'unauthorized',message:error instanceof Error ? error.message : 'unauthorized'});
  }
});
