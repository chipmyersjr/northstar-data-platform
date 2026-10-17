-- Example query run by `make queries`: Gross-margin percentage by customer and reporting month.
select
    customer_id,
    customer_name,
    reporting_month,
    gross_margin
from published.customer_monthly_metrics
order by customer_id, reporting_month;
