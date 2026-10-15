-- Checks that every raw workspace row appears in staging and every staging row points to a raw row.
select
    raw_workspaces.rowid as raw_source_row_id,
    staged.source_row_id
from {{ source('northstar_raw', 'workspaces') }} as raw_workspaces
full outer join {{ ref('stg_workspaces') }} as staged
    on raw_workspaces.rowid = staged.source_row_id
where raw_workspaces.rowid is null
    or staged.source_row_id is null
