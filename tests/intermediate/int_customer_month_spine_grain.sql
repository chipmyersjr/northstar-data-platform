-- Checks that each customer has only one spine row per reporting month.
select customer_id, reporting_month
from {{ ref('int_customer_month_spine') }}
group by customer_id, reporting_month
having count(*) > 1
