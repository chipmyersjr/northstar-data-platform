-- Example query run by `make queries`: Cloud cost by customer and reporting month.
select
    customer_id,
    customer_name,
    reporting_month,
    cloud_cost_usd
from published.customer_monthly_metrics
order by customer_id, reporting_month;
