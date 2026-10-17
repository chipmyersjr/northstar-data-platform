-- Example query run by `make queries`: Product usage by customer and reporting month.
select
    customer_id,
    customer_name,
    reporting_month,
    product_usage_active_users,
    product_usage_api_calls
from published.customer_monthly_metrics
order by customer_id, reporting_month;
