-- Shared helper view defining customer-month reporting periods for subscription, usage, and cloud-cost models.
-- One row per customer per reporting month, from the month of the earliest resolved contract start
-- or mapped workspace creation through the shared reporting cutoff.
-- Keeps reporting-window logic in one place, simplifies downstream SQL, and is easy to inspect and debug.
-- For internal transformations only; analysts should use the published tables.
--
-- Example data:
-- | customer_id | reporting_month |
-- | ----------- | --------------- |
-- | C1          | 2026-03-01      |
-- | C1          | 2026-04-01      |
-- | C2          | 2026-04-01      |
{{ config(materialized='view', schema='intermediate') }}

with common_months as (
    select usage_month
    from {{ ref('stg_usage') }}
    where usage_month is not null

    intersect

    select usage_month
    from {{ ref('stg_cloud_costs') }}
    where usage_month is not null
),
reporting_cutoff as (
    select coalesce(
        max(usage_month),
        error('No common reporting month exists in stg_usage and stg_cloud_costs')
    ) as reporting_month
    from common_months
),
customer_start_dates as (
    select customer_id, starts_on
    from {{ ref('fct_contracts') }}
    where resolution_status = 'resolved'

    union all

    select mapping.customer_id, workspace.created_at as starts_on
    from {{ ref('dim_workspaces') }} as workspace
    join {{ ref('map_customer_workspaces') }} as mapping
        on workspace.workspace_id = mapping.workspace_id
    where mapping.resolution_status = 'resolved'
),
customer_starts as (
    select customer_id, min(starts_on) as starts_on
    from customer_start_dates
    group by customer_id
),
reporting_months as (
    select cast(month.reporting_month as date) as reporting_month
    from reporting_cutoff as cutoff
    cross join generate_series(
        cast(date_trunc('month', (select min(starts_on) from customer_starts)) as date),
        cutoff.reporting_month,
        interval '1 month'
    ) as month(reporting_month)
),
customer_months as (
    select customer.customer_id, month.reporting_month
    from {{ ref('dim_customer') }} as customer
    join customer_starts as start
        on customer.customer_id = start.customer_id
    join reporting_months as month
        on month.reporting_month >= cast(date_trunc('month', start.starts_on) as date)
)
select customer_id, reporting_month
from customer_months
