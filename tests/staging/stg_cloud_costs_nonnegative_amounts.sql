-- Checks that compute and storage costs are nonnegative; observed zero costs are allowed.
select source_row_id
from {{ ref('stg_cloud_costs') }}
where compute_cost_usd < 0
    or storage_cost_usd < 0
