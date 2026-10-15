{{ config(materialized='table', schema='canonical', contract={'enforced': true}) }}

select
    workspace_id,
    created_at,
    deleted_at,
    source_row_id
from {{ ref('stg_workspaces') }}
