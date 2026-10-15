-- Checks that costs are nonnegative with cent precision and reporting dates are the first day of the month.
select source_row_id
from {{ ref('fct_workspace_cloud_costs') }}
where compute_cost_usd < 0
    or storage_cost_usd < 0
    or compute_cost_usd != round(compute_cost_usd, 2)
    or storage_cost_usd != round(storage_cost_usd, 2)
    or usage_month != cast(date_trunc('month', usage_month) as date)
