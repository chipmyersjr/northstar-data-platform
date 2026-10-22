{{ config(materialized='table', schema='canonical', contract={'enforced': true}) }}

select
    cost.cost_id,
    cost.workspace_id,
    case
        when mapping.resolution_status = 'resolved' then mapping.customer_id
    end as customer_id,
    case
        when cost.workspace_id is null then 'missing_workspace'
        when mapping.workspace_id is null then 'unknown_workspace'
        when mapping.resolution_status = 'resolved' then 'resolved'
        else 'unresolved_customer'
    end as resolution_status,
    case
        when workspace.workspace_id is null then 'unknown'
        when workspace.created_at > last_day(cost.usage_month) then 'pre_creation'
        when workspace.deleted_at < cost.usage_month then 'post_deletion'
        else 'active'
    end as lifecycle_status,
    cost.usage_month,
    cost.compute_cost_usd,
    cost.storage_cost_usd,
    cost.source_batch,
    cost.extracted_at,
    cost.source_row_id
from {{ ref('stg_cloud_costs') }} as cost
left join {{ ref('map_customer_workspaces') }} as mapping
    on cost.workspace_id = mapping.workspace_id
left join {{ ref('dim_workspaces') }} as workspace
    on cost.workspace_id = workspace.workspace_id
