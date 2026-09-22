import { withSupabase } from 'npm:@supabase/server@1.7.0';
import { response, appCorsConfig } from '../_shared/server.ts';

export default {
  fetch: withSupabase({ auth:'user', cors:appCorsConfig(), errors:{detailed:false} }, async(req,ctx)=>{
    if(req.method!=='POST') return response({error:'method_not_allowed'},405);
    try{
      const body=await req.json();
      const documentId=String(body.document_id||'').trim();
      if(!documentId) return response({error:'document_id_required'},400);

      const {data:doc,error}=await ctx.supabase
        .from('documents')
        .select('id,storage_path,portal_visible')
        .eq('id',documentId)
        .eq('portal_visible',true)
        .maybeSingle();

      if(error||!doc) return response({error:'document_not_accessible'},403);

      const {data:signed,error:signError}=await ctx.supabaseAdmin.storage
        .from('client-documents')
        .createSignedUrl(doc.storage_path,300);

      if(signError||!signed?.signedUrl) return response({error:'document_link_failed'},500);
      return response({ok:true,url:signed.signedUrl,expires_in:300});
    }catch(error){
      return response({error:'document_link_failed'},400);
    }
  })
};
