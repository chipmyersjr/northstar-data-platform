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
    case
        when workspace.workspace_id is null then 'unknown'
        when workspace.created_at > last_day(usage.usage_month) then 'pre_creation'
        when workspace.deleted_at < usage.usage_month then 'post_deletion'
        else 'active'
    end as lifecycle_status,
    usage.usage_month,
    usage.active_users,
    usage.api_calls,
    usage.source_batch,
    usage.extracted_at,
    usage.source_row_id
from {{ ref('stg_usage') }} as usage
left join {{ ref('map_customer_workspaces') }} as mapping
    on usage.workspace_id = mapping.workspace_id
left join {{ ref('dim_workspaces') }} as workspace
    on usage.workspace_id = workspace.workspace_id
