-- Checks whether each active workspace has usage and cloud-cost records for the month.
-- One row per active, resolved workspace per reporting month.
-- Both published models use these checks to determine customer-month eligibility and report missing records.
-- A view keeps this reusable logic queryable without a separately stored table.
-- For internal transformations only; analysts should use the published tables.
--
-- Example data:
-- | customer_id | reporting_month | workspace_id | has_usage | has_cost |
-- | ----------- | --------------- | ------------ | --------- | -------- |
-- | C1          | 2026-04-01      | W1           | true      | true     |
-- | C1          | 2026-04-01      | W2           | false     | true     |
-- | C2          | 2026-04-01      | W3           | true      | false    |
{{ config(materialized='view', schema='intermediate') }}

with active_workspaces as (
    select spine.customer_id, spine.reporting_month, workspace.workspace_id
    from {{ ref('int_customer_month_spine') }} as spine
    join {{ ref('map_customer_workspaces') }} as mapping
        on spine.customer_id = mapping.customer_id
        and mapping.resolution_status = 'resolved'
    join {{ ref('dim_workspaces') }} as workspace
        on mapping.workspace_id = workspace.workspace_id
        and workspace.created_at <= last_day(spine.reporting_month)
        and (workspace.deleted_at is null or workspace.deleted_at >= spine.reporting_month)
)
select
    workspace.customer_id,
    workspace.reporting_month,
    workspace.workspace_id,
    exists (
        select 1
        from {{ ref('fct_workspace_usage') }} as usage
        where usage.customer_id = workspace.customer_id
            and usage.workspace_id = workspace.workspace_id
            and usage.usage_month = workspace.reporting_month
            and usage.resolution_status = 'resolved'
            and usage.active_users is not null
            and usage.api_calls is not null
    ) as has_usage,
    exists (
        select 1
        from {{ ref('fct_workspace_cloud_costs') }} as cost
        where cost.customer_id = workspace.customer_id
            and cost.workspace_id = workspace.workspace_id
            and cost.usage_month = workspace.reporting_month
            and cost.resolution_status = 'resolved'
            and cost.compute_cost_usd is not null
            and cost.storage_cost_usd is not null
    ) as has_cost
from active_workspaces as workspace
