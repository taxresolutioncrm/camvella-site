import { admin, json, requireUser, corsHeaders } from '../_shared/server.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(req) });
  if (req.method !== 'POST') return json(req,405,{error:'method_not_allowed'});
  try {
    const user = await requireUser(req);
    const body = await req.json();
    const organizationName = String(body.organization_name || '').trim();
    const officeName = String(body.office_name || 'Main Office').trim();
    if (organizationName.length < 2) return json(req,400,{error:'organization_name_required'});

    const { data, error } = await admin.rpc('bootstrap_tenant',{
      p_user_id:user.id,
      p_org_name:organizationName,
      p_office_name:officeName,
      p_email:user.email || null
    });
    if (error) return json(req,400,{error:'bootstrap_failed',message:error.message});
    return json(req,200,{ok:true,...data});
  } catch (error) {
    return json(req,401,{error:'unauthorized',message:error instanceof Error ? error.message : 'unauthorized'});
  }
});
