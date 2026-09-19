# Storage Test Matrix

Run through the Supabase Storage client after the dedicated project is connected.

## Path conventions
- client-documents: <organization_id>/<office-or-shared>/<client_id>/<agency|portal|shared>/<filename>
- enrollment-evidence: <organization_id>/<office-or-shared>/<enrollment_id>/<filename>
- communications: <organization_id>/<office-or-shared>/<communication_id>/<filename>
- commission-statements: <organization_id>/<office-or-shared>/<commission_statement_id>/<filename>
- imports: <organization_id>/<office-or-shared>/<import_type>/<filename>

## Required tests
S1 assigned agent can upload/read an agency-path client document for an assigned client.
S2 assigned agent cannot read another agent's client document.
S3 revenue cannot read client-documents.
S4 compliance can read/write enrollment-evidence.
S5 AAL2 revenue can read/write commission-statements.
S6 AAL1 revenue cannot read/write commission-statements.
S7 manager can read commission-statements at AAL2 but cannot modify them.
S8 portal user can read own portal/shared client-document paths.
S9 portal user can upload only into own portal path.
S10 portal user cannot upload into agency/shared paths.
S11 portal user cannot update/delete an agency-managed client document.
S12 portal user cannot access another client's path.
S13 management can access imports only at AAL2.
S14 agent/revenue/portal roles cannot access imports.
S15 cross-organization paths are blocked for every browser role.
S16 malformed paths are denied.
S17 communications attachment access follows communication/client role rules.
S18 database metadata path guards reject document/enrollment/import/commission records whose storage_path points at a different tenant/entity.
S19 bucket file-size cap rejects objects larger than 25 MB.
S20 signed URLs for portal documents are issued only when the caller has SELECT access to that object.
S21 client-document paths with the wrong office segment are denied even when organization/client IDs match.
S22 enrollment-evidence paths with the wrong office segment are denied.
S23 import paths with the wrong office segment are denied.
S24 shared portal paths require a matching portal-visible document metadata row.

All five buckets remain private.
