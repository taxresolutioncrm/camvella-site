-- 081_storage_type_and_size_limits.sql
-- Enforces bucket-level limits for the file types the current workflows actually process.
-- DO NOT APPLY until the dedicated Supabase project is selected.

update storage.buckets
set
  file_size_limit=26214400,
  allowed_mime_types=array[
    'application/pdf',
    'image/jpeg',
    'image/png',
    'image/heic',
    'image/heif',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'text/plain'
  ]::text[]
where id in ('client-documents','enrollment-evidence');

update storage.buckets
set
  file_size_limit=5242880,
  allowed_mime_types=array[
    'text/csv',
    'application/csv',
    'application/vnd.ms-excel',
    'text/plain'
  ]::text[]
where id='imports';

update storage.buckets
set
  file_size_limit=10485760,
  allowed_mime_types=array[
    'text/csv',
    'application/csv',
    'application/vnd.ms-excel',
    'text/plain'
  ]::text[]
where id='commission-statements';

-- Communication attachments stay private and size-limited while provider-specific
-- MIME requirements remain unknown.
update storage.buckets
set file_size_limit=26214400
where id='communications';
