-- Checks that each customer has only one cloud-cost row per reporting month.
select customer_id, reporting_month
from {{ ref('int_customer_monthly_cloud_costs') }}
group by customer_id, reporting_month
having count(*) > 1
