-- Checks that observed cloud-cost totals are nonnegative; missing totals may remain null.
select customer_id, reporting_month
from {{ ref('int_customer_monthly_cloud_costs') }}
where cloud_cost_usd < 0
