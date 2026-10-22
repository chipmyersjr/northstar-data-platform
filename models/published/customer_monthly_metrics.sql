{{ config(materialized='table', schema='published', contract={'enforced': true}) }}

with eligible_customer_months as (
    select customer_id, reporting_month
    from {{ ref('int_workspace_month_coverage') }}
    group by customer_id, reporting_month
    having bool_and(has_usage and has_cost)
)
select
    eligible.customer_id,
    customer.customer_name,
    eligible.reporting_month,
    subscription.annualized_subscription_value_usd,
    subscription.monthly_subscription_revenue_usd,
    usage.product_usage_active_users,
    usage.product_usage_api_calls,
    cost.cloud_cost_usd,
    cast(round(
        (subscription.monthly_subscription_revenue_usd - cost.cloud_cost_usd)
        / nullif(subscription.monthly_subscription_revenue_usd, 0) * 100,
        4
    ) as decimal(18, 4)) as gross_margin
from eligible_customer_months as eligible
inner join {{ ref('int_customer_subscription_metrics') }} as subscription
    using (customer_id, reporting_month)
inner join {{ ref('int_customer_monthly_usage') }} as usage
    using (customer_id, reporting_month)
inner join {{ ref('int_customer_monthly_cloud_costs') }} as cost
    using (customer_id, reporting_month)
inner join {{ ref('dim_customer') }} as customer
    using (customer_id)
