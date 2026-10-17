-- Example query run by `make queries`: Annualized subscription value by customer and reporting month.
select
    customer_id,
    customer_name,
    reporting_month,
    annualized_subscription_value_usd
from published.customer_monthly_metrics
order by customer_id, reporting_month;
