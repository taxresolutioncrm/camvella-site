import { withSupabase } from 'npm:@supabase/server@1.7.0';
import { response, userIdFromClaims, appCorsConfig } from '../_shared/server.ts';

function safeName(name:string){
  return String(name||'document').replace(/[^a-zA-Z0-9._-]+/g,'-').slice(-160);
}

export default {
  fetch: withSupabase({ auth:'user', cors:appCorsConfig(), errors:{detailed:false} }, async(req,ctx)=>{
    if(req.method!=='POST') return response({error:'method_not_allowed'},405);
    try{
      userIdFromClaims(ctx.userClaims as Record<string,unknown>);
      const body=await req.json();
      const documentId=String(body.document_id||'').trim();
      if(!documentId) return response({error:'document_id_required'},400);

      const {data:doc,error:docError}=await ctx.supabase.from('documents')
        .select('id,organization_id,office_id,client_id,file_name,storage_path,portal_visible')
        .eq('id',documentId).maybeSingle();
      if(docError||!doc||!doc.client_id) return response({error:'document_not_accessible'},403);

      if(doc.portal_visible&&String(doc.storage_path).split('/')[3]==='shared'){
        return response({ok:true,document_id:doc.id,storage_path:doc.storage_path,already_shared:true});
      }

      const parts=String(doc.storage_path||'').split('/');
      if(parts.length<5||parts[0]!==doc.organization_id||parts[2]!==doc.client_id){
        return response({error:'invalid_existing_document_path'},409);
      }

      const destination=[
        doc.organization_id,
        doc.office_id||'shared',
        doc.client_id,
        'shared',
        crypto.randomUUID()+'-'+safeName(doc.file_name)
      ].join('/');

      const {error:moveError}=await ctx.supabaseAdmin.storage
        .from('client-documents')
        .move(doc.storage_path,destination);
      if(moveError) return response({error:'document_share_move_failed',message:moveError.message},400);

      const {data:updated,error:updateError}=await ctx.supabaseAdmin.from('documents')
        .update({storage_path:destination,portal_visible:true})
        .eq('id',doc.id)
        .eq('organization_id',doc.organization_id)
        .select('id,storage_path,portal_visible')
        .single();

      if(updateError){
        await ctx.supabaseAdmin.storage.from('client-documents').move(destination,doc.storage_path);
        return response({error:'document_share_metadata_failed',message:updateError.message},400);
      }

      return response({ok:true,...updated});
    }catch(error){
      return response({error:'document_share_failed',message:error instanceof Error?error.message:'document_share_failed'},400);
    }
  })
};