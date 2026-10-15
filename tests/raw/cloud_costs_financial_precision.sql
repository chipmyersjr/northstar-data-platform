-- Checks that costs are decimal amounts with no extra nonzero fractional digits; trailing zeros are allowed.
select rowid as source_row_id
from {{ source('northstar_raw', 'cloud_costs') }}
where (
    nullif(trim(compute_cost_usd), '') is not null
    and not regexp_full_match(trim(compute_cost_usd), '[+-]?([0-9]+(\.[0-9]{0,2}0*)?|\.[0-9]{1,2}0*)')
)
    or (
        nullif(trim(storage_cost_usd), '') is not null
        and not regexp_full_match(trim(storage_cost_usd), '[+-]?([0-9]+(\.[0-9]{0,2}0*)?|\.[0-9]{1,2}0*)')
    )
