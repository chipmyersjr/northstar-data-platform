{{ config(materialized='table', schema='intermediate', contract={'enforced': true}) }}

with cost_totals as (
    select
        customer_id,
        usage_month as reporting_month,
        cast(sum(compute_cost_usd + storage_cost_usd) as decimal(18, 2)) as cloud_cost_usd
    from {{ ref('fct_workspace_cloud_costs') }}
    where resolution_status = 'resolved'
    group by customer_id, usage_month
)
select
    spine.customer_id,
    'resolved' as resolution_status,
    spine.reporting_month,
    costs.cloud_cost_usd
from {{ ref('int_customer_month_spine') }} as spine
left join cost_totals as costs
    on spine.customer_id = costs.customer_id
    and spine.reporting_month = costs.reporting_month
