-- Aggregates resolved workspace usage into one row per customer per month with observed usage.
-- Months without observations have no row; missing usage is not converted to zero.
-- These totals combine with the other intermediate metrics in published customer reporting.
-- For internal transformations only; analysts should use the published tables.
--
-- Example data:
-- | customer_id | resolution_status | reporting_month | product_usage_active_users | product_usage_api_calls |
-- | ----------- | ----------------- | --------------- | -------------------------- | ----------------------- |
-- | C1          | resolved          | 2026-03-01      | 7                          | 100                     |
-- | C1          | resolved          | 2026-04-01      | 0                          | 0                       |
-- | C2          | resolved          | 2026-04-01      | 3                          | 50                      |
{{ config(materialized='table', schema='intermediate', contract={'enforced': true}) }}

with usage_totals as (
    select
        customer_id,
        usage_month as reporting_month,
        cast(sum(active_users) as bigint) as product_usage_active_users,
        cast(sum(api_calls) as bigint) as product_usage_api_calls
    from {{ ref('fct_workspace_usage') }}
    where resolution_status = 'resolved'
    group by customer_id, usage_month
)
select
    usage.customer_id,
    'resolved' as resolution_status,
    usage.reporting_month,
    usage.product_usage_active_users,
    usage.product_usage_api_calls
from usage_totals as usage
join {{ ref('int_customer_month_spine') }} as spine
    on usage.customer_id = spine.customer_id
    and usage.reporting_month = spine.reporting_month
