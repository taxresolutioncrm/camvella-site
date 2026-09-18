-- 064_team_invite_active_uniqueness.sql
-- Preserves accepted team-invite history while preventing duplicate active invitations.
-- DO NOT APPLY until the dedicated Supabase project is selected.

create unique index team_invitations_active_email_uq
on public.team_invitations(organization_id,lower(email))
where accepted_at is null;
