-- seed.sql
-- Deterministic sandbox fixture. Replace auth user UUIDs only after project selection.

insert into public.organizations(id,name,status)
values
('11111111-1111-1111-1111-111111111111','Sandbox Agency','active')
on conflict do nothing;

insert into public.offices(id,organization_id,name,timezone,email,phone,fax)
values
('22222222-2222-2222-2222-222222222222','11111111-1111-1111-1111-111111111111','Main Office','America/New_York','info@example.test','561-555-0100','561-555-0199')
on conflict do nothing;

insert into public.carriers(id,organization_id,name,market,status) values
('33333333-3333-3333-3333-333333333331','11111111-1111-1111-1111-111111111111','Ambetter','aca','active'),
('33333333-3333-3333-3333-333333333332','11111111-1111-1111-1111-111111111111','Florida Blue','aca','active'),
('33333333-3333-3333-3333-333333333333','11111111-1111-1111-1111-111111111111','Humana','medicare','active')
on conflict do nothing;

insert into public.clients(id,organization_id,office_id,first_name,last_name,email,phone,market,portal_status,renewal_risk)
values
('44444444-4444-4444-4444-444444444441','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','Angela','Reed','angela@example.test','561-555-0121','aca','active','low'),
('44444444-4444-4444-4444-444444444442','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','Robert','King','robert@example.test','561-555-0122','medicare','active','low'),
('44444444-4444-4444-4444-444444444443','11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','Marcus','Hill','marcus@example.test','561-555-0123','aca','invited','high')
on conflict do nothing;
