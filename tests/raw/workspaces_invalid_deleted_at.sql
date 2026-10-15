-- Checks that nonempty deletion dates can be parsed as dates; missing dates are allowed.
select rowid as source_row_id
from {{ source('northstar_raw', 'workspaces') }}
where nullif(trim(deleted_at), '') is not null
    and try_cast(deleted_at as date) is null
