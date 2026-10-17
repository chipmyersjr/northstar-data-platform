{{ config(materialized='table', schema='staging', contract={'enforced': true}) }}

select
    rowid as source_row_id,
    nullif(upper(trim(contract_id)), '') as contract_id,
    nullif(upper(trim(account_id)), '') as account_id,
    nullif(trim(plan), '') as plan,
    nullif(lower(trim(billing_period)), '') as billing_period,
    try_cast(nullif(trim(recurring_amount_usd), '') as decimal(18, 2)) as recurring_amount_usd,
    try_cast(nullif(trim(starts_on), '') as date) as starts_on,
    try_cast(nullif(trim(ends_on), '') as date) as ends_on,
    nullif(lower(trim(status)), '') as status,
    source_batch,
    try_cast(nullif(trim(extracted_at), '') as timestamp with time zone) as extracted_at
from {{ source('northstar_raw', 'contracts_batch1') }}
