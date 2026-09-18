import { admin, json, requireUser, corsHeaders } from '../_shared/server.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok',{headers:corsHeaders(req)});
  if (req.method !== 'POST') return json(req,405,{error:'method_not_allowed'});
  try {
    const user=await requireUser(req);
    const body=await req.json();
    const clientId=String(body.client_id||'');
    const email=String(body.email||'').trim();
    if(!clientId||!email) return json(req,400,{error:'client_id_and_email_required'});

    const {data,error}=await admin.rpc('create_portal_invitation',{
      p_actor_user_id:user.id,
      p_client_id:clientId,
      p_email:email,
      p_hours_valid:72
    });
    if(error) return json(req,400,{error:'portal_invite_create_failed',message:error.message});

    return json(req,200,{ok:true,invitation_id:data.invitation_id,token:data.token,email:data.email});
  } catch(error) {
    return json(req,401,{error:'unauthorized',message:error instanceof Error?error.message:'unauthorized'});
  }
});
