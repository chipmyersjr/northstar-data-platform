-- This disposable model proves that the raw warehouse and dbt profile work.
-- It intentionally excludes the source columns containing PII.
select
    trim(upper(account_id)) as account_id,
    segment,
    region,
    try_cast(updated_at as timestamp) as updated_at
from {{ source('northstar_raw', 'accounts') }}
