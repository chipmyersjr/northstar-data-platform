-- Checks that recurring contract amounts are not negative; zero is allowed.
select source_row_id
from {{ ref('stg_contracts') }}
where recurring_amount_usd < 0
