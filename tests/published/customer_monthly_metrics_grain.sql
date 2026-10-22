-- Checks that each eligible customer-month appears only once.
select customer_id, reporting_month
from {{ ref('customer_monthly_metrics') }}
group by customer_id, reporting_month
having count(*) > 1
