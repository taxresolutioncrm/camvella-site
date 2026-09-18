# Storage Test Matrix

Run through the Supabase Storage client after the dedicated project is connected.

## Path conventions
- client-documents: <organization_id>/<office-or-shared>/<client_id>/<filename>
- enrollment-evidence: <organization_id>/<office-or-shared>/<enrollment_id>/<filename>
- communications: <organization_id>/<office-or-shared>/<communication_id>/<filename>
- commission-statements: <organization_id>/<office-or-shared>/<commission_statement_id>/<filename>

## Required tests
S1 assigned agent can upload/read a client document for an assigned client.
S2 assigned agent cannot read another agent's client document.
S3 revenue cannot read client-documents.
S4 compliance can read/write enrollment-evidence.
S5 revenue can read/write commission-statements.
S6 manager can read commission-statements but cannot modify them.
S7 portal user can read/upload own client-documents path.
S8 portal user cannot update/delete an agency-managed client document.
S9 portal user cannot access another client's path.
S10 cross-organization paths are blocked for all browser roles.
S11 malformed paths are denied.
S12 communications attachment access follows communication/client role rules.

All four buckets remain private.
