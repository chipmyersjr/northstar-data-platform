{{ config(materialized='table', schema='canonical', contract={'enforced': true}) }}

select
    contract.contract_id,
    customer.customer_id,
    case
        when customer.customer_id is not null then 'resolved'
        else 'unresolved_customer'
    end as resolution_status,
    contract.plan,
    contract.billing_period,
    contract.recurring_amount_usd,
    contract.starts_on,
    contract.ends_on,
    contract.status,
    contract.source_batch,
    contract.extracted_at,
    contract.source_row_id
from {{ ref('stg_contracts') }} as contract
left join {{ ref('dim_customer') }} as customer
    on contract.account_id = customer.customer_id
