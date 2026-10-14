-- Checks that nonempty contract end dates can be parsed; missing dates are allowed here.
select rowid as source_row_id
from {{ source('northstar_raw', 'contracts_batch1') }}
where nullif(trim(ends_on), '') is not null
    and try_cast(ends_on as date) is null
