-- Checks that a workspace is not deleted before it was created.
select source_row_id
from {{ ref('stg_workspaces') }}
where deleted_at < created_at
