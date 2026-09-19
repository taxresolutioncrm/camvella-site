-- 089_browser_hard_delete_boundary.sql
-- Extends append-only browser behavior to scheduling and configuration records.
-- Trusted service-role maintenance remains available when a real deletion is required.
-- DO NOT APPLY until the dedicated Supabase project is selected.

revoke delete on
  public.offices,
  public.carriers,
  public.carrier_products,
  public.appointments,
  public.tasks,
  public.provider_connections,
  public.communication_endpoints,
  public.scheduling_availability_rules,
  public.booking_links,
  public.appointment_types,
  public.communication_templates,
  public.public_intake_forms,
  public.automation_rules,
  public.notification_preferences
from authenticated;
