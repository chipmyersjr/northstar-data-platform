-- Checks that every raw usage row appears in staging and every staging row points to a raw row.
select
    raw_usage.rowid as raw_source_row_id,
    staged.source_row_id
from {{ source('northstar_raw', 'usage_batch1') }} as raw_usage
full outer join {{ ref('stg_usage') }} as staged
    on raw_usage.rowid = staged.source_row_id
where raw_usage.rowid is null
    or staged.source_row_id is null
