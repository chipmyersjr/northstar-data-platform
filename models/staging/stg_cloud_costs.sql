{{ config(materialized='table', schema='staging', contract={'enforced': true}) }}

select
    rowid as source_row_id,
    nullif(upper(trim(cost_id)), '') as cost_id,
    nullif(upper(trim(workspace_id)), '') as workspace_id,
    cast(date_trunc('month', try_cast(nullif(trim(usage_month), '') as date)) as date) as usage_month,
    try_cast(nullif(trim(compute_cost_usd), '') as decimal(18, 2)) as compute_cost_usd,
    try_cast(nullif(trim(storage_cost_usd), '') as decimal(18, 2)) as storage_cost_usd,
    source_batch,
    try_cast(nullif(trim(extracted_at), '') as timestamp with time zone) as extracted_at
from {{ source('northstar_raw', 'cloud_costs') }}
