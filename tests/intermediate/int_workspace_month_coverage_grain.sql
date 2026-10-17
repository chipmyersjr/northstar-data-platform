-- Checks that each active mapped workspace appears once per customer and reporting month.
select customer_id, reporting_month, workspace_id
from {{ ref('int_workspace_month_coverage') }}
group by customer_id, reporting_month, workspace_id
having count(*) > 1
