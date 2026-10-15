-- Checks that every staging charge is preserved with identical identifiers, exact amounts, dates, and metadata.
select coalesce(cost.source_row_id, staged.source_row_id) as source_row_id
from {{ ref('fct_workspace_cloud_costs') }} as cost
full outer join {{ ref('stg_cloud_costs') }} as staged
    on cost.source_row_id = staged.source_row_id
where cost.source_row_id is null
    or staged.source_row_id is null
    or cost.cost_id is distinct from staged.cost_id
    or cost.workspace_id is distinct from staged.workspace_id
    or cost.usage_month is distinct from staged.usage_month
    or cost.compute_cost_usd is distinct from staged.compute_cost_usd
    or cost.storage_cost_usd is distinct from staged.storage_cost_usd
    or cost.source_batch is distinct from staged.source_batch
    or cost.extracted_at is distinct from staged.extracted_at
