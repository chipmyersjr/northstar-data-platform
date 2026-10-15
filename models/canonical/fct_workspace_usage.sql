{{ config(materialized='table', schema='canonical', contract={'enforced': true}) }}

select
    usage.usage_id,
    usage.workspace_id,
    case
        when mapping.resolution_status = 'resolved' then mapping.customer_id
    end as customer_id,
    case
        when usage.workspace_id is null then 'missing_workspace'
        when mapping.workspace_id is null then 'unknown_workspace'
        when mapping.resolution_status = 'resolved' then 'resolved'
        else 'unresolved_customer'
    end as resolution_status,
    usage.usage_month,
    usage.active_users,
    usage.api_calls,
    usage.source_batch,
    usage.extracted_at,
    usage.source_row_id
from {{ ref('stg_usage') }} as usage
left join {{ ref('map_customer_workspaces') }} as mapping
    on usage.workspace_id = mapping.workspace_id
