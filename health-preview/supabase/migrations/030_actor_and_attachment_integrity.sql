-- 030_actor_and_attachment_integrity.sql
-- Tightens actor attribution and communication attachment consistency.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create trigger userorg_communications_user_id
before insert or update on public.communications
for each row execute function app_private.guard_user_organization('user_id');

create trigger userorg_documents_uploaded_by
before insert or update on public.documents
for each row execute function app_private.guard_user_organization('uploaded_by');

create trigger userorg_tasks_created_by
before insert or update on public.tasks
for each row execute function app_private.guard_user_organization('created_by');

create trigger userorg_plan_comparisons_created_by
before insert or update on public.plan_comparisons
for each row execute function app_private.guard_user_organization('created_by');

create trigger userorg_portal_invitations_created_by
before insert or update on public.portal_invitations
for each row execute function app_private.guard_user_organization('created_by');

create trigger userorg_contact_preferences_updated_by
before insert or update on public.contact_preferences
for each row execute function app_private.guard_user_organization('updated_by');

create trigger userorg_notification_preferences_user_id
before insert or update on public.notification_preferences
for each row execute function app_private.guard_user_organization('user_id');

create trigger userorg_app_notifications_user_id
before insert or update on public.app_notifications
for each row execute function app_private.guard_user_organization('user_id');

create or replace function app_private.guard_communication_attachment_alignment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  comm_client uuid;
  doc_client uuid;
  comm_org uuid;
  doc_org uuid;
begin
  select organization_id,client_id into comm_org,comm_client
  from public.communications
  where id=new.communication_id;

  select organization_id,client_id into doc_org,doc_client
  from public.documents
  where id=new.document_id;

  if comm_org is null or doc_org is null or comm_org<>doc_org then
    raise exception 'communication attachment organization mismatch';
  end if;

  if comm_client is not null and doc_client is not null and comm_client<>doc_client then
    raise exception 'communication attachment belongs to a different client';
  end if;

  return new;
end;
$$;

revoke all on function app_private.guard_communication_attachment_alignment() from public, anon, authenticated;

create trigger communication_attachment_alignment_guard
before insert or update on public.communication_attachments
for each row execute function app_private.guard_communication_attachment_alignment();
