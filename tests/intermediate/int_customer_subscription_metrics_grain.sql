-- Checks that each customer has only one subscription metrics row per reporting month.
select customer_id, reporting_month
from {{ ref('int_customer_subscription_metrics') }}
group by customer_id, reporting_month
having count(*) > 1
