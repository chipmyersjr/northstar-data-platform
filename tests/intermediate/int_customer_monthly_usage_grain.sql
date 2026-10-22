-- Checks that each customer has only one observed usage row per reporting month.
select customer_id, reporting_month
from {{ ref('int_customer_monthly_usage') }}
group by customer_id, reporting_month
having count(*) > 1
