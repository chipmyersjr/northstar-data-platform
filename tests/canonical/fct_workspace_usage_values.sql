-- Checks that usage counts are nonnegative and reporting dates are the first day of the month.
select source_row_id
from {{ ref('fct_workspace_usage') }}
where active_users < 0
    or api_calls < 0
    or usage_month != cast(date_trunc('month', usage_month) as date)
