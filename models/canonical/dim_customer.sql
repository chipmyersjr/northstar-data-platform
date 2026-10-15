{{ config(materialized='table', schema='canonical', contract={'enforced': true}) }}

select
    account_id as customer_id,
    account_name as customer_name,
    segment,
    region,
    updated_at,
    source_row_id
from {{ ref('stg_accounts') }}
