# Commission Statement Normalization

## Statement
- id
- organization_id
- carrier_id
- statement_period_start
- statement_period_end
- received_at
- source_filename
- total_amount
- row_count
- import_status

## Normalized commission line
- id
- statement_id
- external_member_id nullable
- external_policy_number nullable
- client_id nullable
- policy_id nullable
- producer_external_id nullable
- user_id nullable
- commission_type
- gross_amount
- split_amount nullable
- net_amount
- effective_date nullable
- paid_date nullable
- match_status
- exception_reason nullable

## Match order
1. Exact carrier + policy number
2. Exact external member ID
3. Client + product + effective date candidate
4. Manual review

## Exception reasons
- no_policy_match
- no_client_match
- producer_mismatch
- split_mismatch
- unexpected_chargeback
- short_pay
- duplicate_line
- unknown_product

## Reconciliation rule
A statement is not considered reconciled until every line is either matched or explicitly dispositioned.
