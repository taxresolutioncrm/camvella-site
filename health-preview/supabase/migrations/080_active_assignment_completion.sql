-- 080_active_assignment_completion.sql
-- Completes active-member guards for live assignment fields omitted from earlier coverage.
-- DO NOT APPLY until the dedicated Supabase project is selected.

drop trigger if exists userorg_communication_threads_assigned_user_id
on public.communication_threads;

create trigger userorg_communication_threads_assigned_user_id
before insert or update of assigned_user_id,organization_id,office_id
on public.communication_threads
for each row execute function app_private.guard_active_assignment('assigned_user_id');

drop trigger if exists userorg_carrier_contracts_user_id
on public.carrier_contracts;

create trigger userorg_carrier_contracts_user_id
before insert or update of user_id,organization_id
on public.carrier_contracts
for each row execute function app_private.guard_active_assignment('user_id');
