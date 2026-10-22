-- Checks that annualized subscription value and estimated monthly revenue are nonnegative.
select customer_id, reporting_month
from {{ ref('int_customer_subscription_metrics') }}
where annualized_subscription_value_usd < 0
    or monthly_subscription_revenue_usd < 0
