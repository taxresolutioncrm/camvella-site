# Security & RLS Test Matrix

## Required tenant-isolation tests
T1 org A cannot SELECT org B lead
T2 org A cannot INSERT row with org B organization_id
T3 org A cannot UPDATE org B client
T4 org A cannot DELETE org B document
T5 agent cannot change organization membership
T6 revenue role cannot submit enrollment
T7 compliance role cannot alter commission statement
T8 office-restricted agent cannot read sibling office if policy restricts it
T9 privileged server operation writes audit entry
T10 exposed view respects invoker permissions
T11 storage object path is organization-scoped

All tests remain pending until a dedicated Supabase project is connected.
