-- Checks that every staging contract is preserved with the same source reference and contract attributes.
select coalesce(contract.source_row_id, staged.source_row_id) as source_row_id
from {{ ref('fct_contracts') }} as contract
full outer join {{ ref('stg_contracts') }} as staged
    on contract.source_row_id = staged.source_row_id
where contract.source_row_id is null
    or staged.source_row_id is null
    or contract.contract_id is distinct from staged.contract_id
    or contract.plan is distinct from staged.plan
    or contract.billing_period is distinct from staged.billing_period
    or contract.recurring_amount_usd is distinct from staged.recurring_amount_usd
    or contract.starts_on is distinct from staged.starts_on
    or contract.ends_on is distinct from staged.ends_on
    or contract.status is distinct from staged.status
    or contract.source_batch is distinct from staged.source_batch
    or contract.extracted_at is distinct from staged.extracted_at
