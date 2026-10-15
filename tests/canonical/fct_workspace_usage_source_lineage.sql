-- Checks that every staging usage row is preserved with the same identifiers, counts, dates, and metadata.
select coalesce(usage.source_row_id, staged.source_row_id) as source_row_id
from {{ ref('fct_workspace_usage') }} as usage
full outer join {{ ref('stg_usage') }} as staged
    on usage.source_row_id = staged.source_row_id
where usage.source_row_id is null
    or staged.source_row_id is null
    or usage.usage_id is distinct from staged.usage_id
    or usage.workspace_id is distinct from staged.workspace_id
    or usage.usage_month is distinct from staged.usage_month
    or usage.active_users is distinct from staged.active_users
    or usage.api_calls is distinct from staged.api_calls
    or usage.source_batch is distinct from staged.source_batch
    or usage.extracted_at is distinct from staged.extracted_at
