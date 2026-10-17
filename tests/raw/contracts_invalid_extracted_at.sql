-- Checks that nonempty extraction timestamps can be parsed with a timezone; missing values are allowed.
select rowid as source_row_id
from {{ source('northstar_raw', 'contracts_batch1') }}
where nullif(trim(extracted_at), '') is not null
    and try_cast(extracted_at as timestamp with time zone) is null
