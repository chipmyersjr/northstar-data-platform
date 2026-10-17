{{ config(materialized='table', schema='published', contract={'enforced': true}) }}

select
    reporting_month,
    'canonical.fct_workspace_usage' as source_table,
    'completeness' as issue_category,
    'missing_usage' as issue_reason,
    workspace_id,
    customer_id,
    cast(null as bigint) as source_row_id,
    cast(null as decimal(18, 2)) as excluded_financial_amount_usd,
    cast(null as bigint) as excluded_active_users,
    cast(null as bigint) as excluded_api_calls
from {{ ref('int_workspace_month_coverage') }}
where not has_usage

union all

select
    reporting_month,
    'canonical.fct_workspace_cloud_costs' as source_table,
    'completeness' as issue_category,
    'missing_cloud_cost' as issue_reason,
    workspace_id,
    customer_id,
    cast(null as bigint) as source_row_id,
    cast(null as decimal(18, 2)) as excluded_financial_amount_usd,
    cast(null as bigint) as excluded_active_users,
    cast(null as bigint) as excluded_api_calls
from {{ ref('int_workspace_month_coverage') }}
where not has_cost

union all

select
    usage_month as reporting_month,
    'canonical.fct_workspace_usage' as source_table,
    'mapping' as issue_category,
    resolution_status as issue_reason,
    workspace_id,
    customer_id,
    source_row_id,
    cast(null as decimal(18, 2)) as excluded_financial_amount_usd,
    active_users as excluded_active_users,
    api_calls as excluded_api_calls
from {{ ref('fct_workspace_usage') }}
where resolution_status <> 'resolved'

union all

select
    usage_month as reporting_month,
    'canonical.fct_workspace_cloud_costs' as source_table,
    'mapping' as issue_category,
    resolution_status as issue_reason,
    workspace_id,
    customer_id,
    source_row_id,
    cast(compute_cost_usd + storage_cost_usd as decimal(18, 2)) as excluded_financial_amount_usd,
    cast(null as bigint) as excluded_active_users,
    cast(null as bigint) as excluded_api_calls
from {{ ref('fct_workspace_cloud_costs') }}
where resolution_status <> 'resolved'
