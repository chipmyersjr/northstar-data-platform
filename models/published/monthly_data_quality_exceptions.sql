{{ config(materialized='table', schema='published', contract={'enforced': true}) }}

with reporting_cutoff as (
    select max(reporting_month) as reporting_month
    from {{ ref('int_customer_month_spine') }}
)
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
    case when resolution_status = 'resolved' then 'lifecycle' else 'mapping' end as issue_category,
    case when resolution_status = 'resolved' then lifecycle_status else resolution_status end as issue_reason,
    workspace_id,
    customer_id,
    source_row_id,
    cast(null as decimal(18, 2)) as excluded_financial_amount_usd,
    active_users as excluded_active_users,
    api_calls as excluded_api_calls
from {{ ref('fct_workspace_usage') }}
where resolution_status <> 'resolved'
    or lifecycle_status in ('post_deletion', 'pre_creation')

union all

select
    usage_month as reporting_month,
    'canonical.fct_workspace_cloud_costs' as source_table,
    case when resolution_status = 'resolved' then 'lifecycle' else 'mapping' end as issue_category,
    case when resolution_status = 'resolved' then lifecycle_status else resolution_status end as issue_reason,
    workspace_id,
    customer_id,
    source_row_id,
    cast(compute_cost_usd + storage_cost_usd as decimal(18, 2)) as excluded_financial_amount_usd,
    cast(null as bigint) as excluded_active_users,
    cast(null as bigint) as excluded_api_calls
from {{ ref('fct_workspace_cloud_costs') }}
where resolution_status <> 'resolved'
    or lifecycle_status in ('post_deletion', 'pre_creation')

union all

select
    cast(month.reporting_month as date) as reporting_month,
    'canonical.fct_contracts' as source_table,
    'mapping' as issue_category,
    resolution_status as issue_reason,
    cast(null as varchar) as workspace_id,
    customer_id,
    source_row_id,
    cast(round(cast(
        case
            when contract.billing_period = 'annual' then contract.recurring_amount_usd / 12
            else contract.recurring_amount_usd
        end * (
            date_diff(
                'day',
                greatest(contract.starts_on, month.reporting_month),
                least(coalesce(contract.ends_on, last_day(month.reporting_month)), last_day(month.reporting_month))
            ) + 1
        ) / day(last_day(month.reporting_month))
    as decimal(38, 12)), 2) as decimal(18, 2)) as excluded_financial_amount_usd,
    cast(null as bigint) as excluded_active_users,
    cast(null as bigint) as excluded_api_calls
from {{ ref('fct_contracts') }} as contract
cross join reporting_cutoff as cutoff
cross join generate_series(
    date_trunc('month', contract.starts_on),
    least(coalesce(contract.ends_on, cutoff.reporting_month), cutoff.reporting_month),
    interval '1 month'
) as month(reporting_month)
where contract.resolution_status <> 'resolved'
