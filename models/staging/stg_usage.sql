{{ config(materialized='table', schema='staging', contract={'enforced': true}) }}

select
    rowid as source_row_id,
    nullif(upper(trim(usage_id)), '') as usage_id,
    nullif(upper(trim(workspace_id)), '') as workspace_id,
    cast(date_trunc('month', try_cast(nullif(trim(usage_month), '') as date)) as date) as usage_month,
    case
        when regexp_full_match(trim(active_users), '[0-9]+')
            then try_cast(trim(active_users) as bigint)
    end as active_users,
    case
        when regexp_full_match(trim(api_calls), '[0-9]+')
            then try_cast(trim(api_calls) as bigint)
    end as api_calls,
    source_batch,
    try_cast(nullif(trim(extracted_at), '') as timestamp with time zone) as extracted_at
from {{ source('northstar_raw', 'usage_batch1') }}
