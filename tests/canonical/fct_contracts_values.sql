-- Checks that amounts are nonnegative, service dates are ordered, and cancelled contracts have end dates.
select source_row_id
from {{ ref('fct_contracts') }}
where recurring_amount_usd < 0
    or ends_on < starts_on
    or (status = 'cancelled' and ends_on is null)
