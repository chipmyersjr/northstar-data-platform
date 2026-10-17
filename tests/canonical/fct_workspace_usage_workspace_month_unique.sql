-- Checks that each nonempty workspace ID has only one usage record per reporting month.
select workspace_id, usage_month
from {{ ref('fct_workspace_usage') }}
where workspace_id is not null
group by workspace_id, usage_month
having count(*) > 1
