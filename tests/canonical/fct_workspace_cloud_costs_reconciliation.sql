-- Checks that all resolved and unresolved canonical charges retain staging compute and storage totals by month.
with staged as (
    select
        usage_month,
        sum(compute_cost_usd) as compute_cost_usd,
        sum(storage_cost_usd) as storage_cost_usd
    from {{ ref('stg_cloud_costs') }}
    group by usage_month
),
canonical as (
    select
        usage_month,
        sum(compute_cost_usd) as compute_cost_usd,
        sum(storage_cost_usd) as storage_cost_usd
    from {{ ref('fct_workspace_cloud_costs') }}
    group by usage_month
)
select coalesce(staged.usage_month, canonical.usage_month) as usage_month
from staged
full outer join canonical
    on staged.usage_month = canonical.usage_month
where staged.usage_month is null
    or canonical.usage_month is null
    or staged.compute_cost_usd is distinct from canonical.compute_cost_usd
    or staged.storage_cost_usd is distinct from canonical.storage_cost_usd
