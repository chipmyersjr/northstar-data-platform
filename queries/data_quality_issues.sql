-- Example query run by `make queries`: Data-quality issues for April 2026.
select
    issue_reason,
    workspace_id,
    excluded_financial_amount_usd as excluded_cost_usd,
    excluded_active_users as active_users,
    excluded_api_calls as api_calls
from published.monthly_data_quality_exceptions
where reporting_month = date '2026-04-01'
order by issue_reason, workspace_id, source_table, source_row_id;
