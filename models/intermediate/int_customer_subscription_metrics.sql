-- Calculates annualized subscription value and estimated revenue, one row per customer per reporting month.
-- Annualized value is a month-end snapshot; revenue reflects inclusive service days, including partial months.
-- Months without qualifying contracts have zero values. Fractional cents are retained through aggregation
-- before revenue is rounded to cents. These metrics support published subscription and gross-margin reporting.
-- For internal transformations only; analysts should use the published tables.
--
-- Example data:
-- | customer_id | reporting_month | annualized_subscription_value_usd | monthly_subscription_revenue_usd |
-- | ----------- | --------------- | --------------------------------- | -------------------------------- |
-- | C1          | 2026-03-01      | 1200.00                           | 100.00                           |
-- | C1          | 2026-04-01      | 0.00                              | 50.00                            |
-- | C2          | 2026-04-01      | 0.00                              | 0.00                             |
{{ config(materialized='table', schema='intermediate', contract={'enforced': true}) }}

with contract_months as (
    select
        contract.customer_id,
        spine.reporting_month,
        contract.ends_on,
        case
            when contract.billing_period = 'annual' then contract.recurring_amount_usd
            else contract.recurring_amount_usd * 12
        end as annualized_amount_usd,
        date_diff(
            'day',
            greatest(contract.starts_on, spine.reporting_month),
            least(coalesce(contract.ends_on, last_day(spine.reporting_month)), last_day(spine.reporting_month))
        ) + 1 as service_days,
        day(last_day(spine.reporting_month)) as calendar_days
    from {{ ref('fct_contracts') }} as contract
    join {{ ref('int_customer_month_spine') }} as spine
        on contract.customer_id = spine.customer_id
        and contract.starts_on <= last_day(spine.reporting_month)
        and (contract.ends_on is null or contract.ends_on >= spine.reporting_month)
    where contract.resolution_status = 'resolved'
),
subscription_totals as (
    select
        customer_id,
        reporting_month,
        cast(sum(case
            when ends_on is null or ends_on >= last_day(reporting_month)
                then annualized_amount_usd
            else 0
        end) as decimal(18, 2)) as annualized_subscription_value_usd,
        cast(round(sum(cast(
            annualized_amount_usd / 12 * service_days / calendar_days
        as decimal(38, 12))), 2) as decimal(18, 2)) as monthly_subscription_revenue_usd
    from contract_months
    group by customer_id, reporting_month
)
select
    spine.customer_id,
    spine.reporting_month,
    coalesce(totals.annualized_subscription_value_usd, cast(0 as decimal(18, 2))) as annualized_subscription_value_usd,
    coalesce(totals.monthly_subscription_revenue_usd, cast(0 as decimal(18, 2))) as monthly_subscription_revenue_usd
from {{ ref('int_customer_month_spine') }} as spine
left join subscription_totals as totals
    on spine.customer_id = totals.customer_id
    and spine.reporting_month = totals.reporting_month
