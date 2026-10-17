-- Checks that end dates are not before start dates and cancelled contracts have an end date.
select source_row_id
from {{ ref('stg_contracts') }}
where ends_on < starts_on
    or (status = 'cancelled' and ends_on is null)
