-- Checks that every raw account row appears in staging and every staging row points to a raw row.
select
    raw_accounts.rowid as raw_source_row_id,
    staged.source_row_id
from {{ source('northstar_raw', 'accounts') }} as raw_accounts
full outer join {{ ref('stg_accounts') }} as staged
    on raw_accounts.rowid = staged.source_row_id
where raw_accounts.rowid is null
    or staged.source_row_id is null
