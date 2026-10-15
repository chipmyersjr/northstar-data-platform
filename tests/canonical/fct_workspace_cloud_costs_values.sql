-- Checks that costs are nonnegative and reporting dates are the first day of the month.
select source_row_id
from {{ ref('fct_workspace_cloud_costs') }}
where compute_cost_usd < 0
    or storage_cost_usd < 0
    or usage_month != cast(date_trunc('month', usage_month) as date)
