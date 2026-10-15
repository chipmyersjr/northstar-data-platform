-- Checks that active-user and API-call counts are nonnegative.
select source_row_id
from {{ ref('stg_usage') }}
where active_users < 0
    or api_calls < 0
