-- Checks original contract amounts for negatives before cent rounding, including small values such as -0.001.
select rowid as source_row_id
from {{ source('northstar_raw', 'contracts_batch1') }}
where try_cast(recurring_amount_usd as double) < 0
