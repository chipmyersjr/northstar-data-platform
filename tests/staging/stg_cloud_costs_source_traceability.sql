-- Checks that every raw cost row appears in staging and every staging row points to a raw row.
select
    raw_costs.rowid as raw_source_row_id,
    staged.source_row_id
from {{ source('northstar_raw', 'cloud_costs') }} as raw_costs
full outer join {{ ref('stg_cloud_costs') }} as staged
    on raw_costs.rowid = staged.source_row_id
where raw_costs.rowid is null
    or staged.source_row_id is null
