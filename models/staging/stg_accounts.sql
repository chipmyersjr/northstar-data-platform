{{ config(materialized='table', schema='staging', contract={'enforced': true}) }}

select
    rowid as source_row_id,
    nullif(upper(trim(account_id)), '') as account_id,
    nullif(trim(account_name), '') as account_name,
    nullif(trim(segment), '') as segment,
    nullif(upper(trim(region)), '') as region,
    try_cast(nullif(trim(updated_at), '') as timestamp with time zone) as updated_at
from {{ source('northstar_raw', 'accounts') }}
