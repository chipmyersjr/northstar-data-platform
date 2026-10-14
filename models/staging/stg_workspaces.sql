{{ config(materialized='table', schema='staging', contract={'enforced': true}) }}

select
    rowid as source_row_id,
    nullif(upper(trim(workspace_id)), '') as workspace_id,
    nullif(upper(trim(crm_account_ref)), '') as crm_account_ref,
    try_cast(nullif(trim(created_at), '') as date) as created_at,
    try_cast(nullif(trim(deleted_at), '') as date) as deleted_at
from {{ source('northstar_raw', 'workspaces') }}
