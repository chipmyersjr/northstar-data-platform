-- Checks that observed customer usage totals are nonnegative.
select customer_id, reporting_month
from {{ ref('int_customer_monthly_usage') }}
where product_usage_active_users < 0
    or product_usage_api_calls < 0
