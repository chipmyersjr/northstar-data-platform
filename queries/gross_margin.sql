-- Example query run by `make queries`: Gross-margin percentage by customer and reporting month.
select
    customer_id,
    customer_name,
    reporting_month,
    monthly_subscription_revenue_usd,
    cloud_cost_usd,
    gross_margin
from published.customer_monthly_metrics
order by customer_id, reporting_month;
