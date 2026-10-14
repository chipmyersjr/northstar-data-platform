-- Checks that every raw contract row appears in staging and every staging row points to a raw row.
select
    raw_contracts.rowid as raw_source_row_id,
    staged.source_row_id
from {{ source('northstar_raw', 'contracts_batch1') }} as raw_contracts
full outer join {{ ref('stg_contracts') }} as staged
    on raw_contracts.rowid = staged.source_row_id
where raw_contracts.rowid is null
    or staged.source_row_id is null
