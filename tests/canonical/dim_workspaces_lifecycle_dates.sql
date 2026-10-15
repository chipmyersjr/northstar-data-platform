-- Checks that a workspace is not deleted before it was created; missing deletion dates are allowed.
select source_row_id
from {{ ref('dim_workspaces') }}
where deleted_at < created_at
