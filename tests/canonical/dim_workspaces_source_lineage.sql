-- Checks that each workspace's ID and lifecycle dates match the staging row identified by its source-row reference.
select workspace.source_row_id
from {{ ref('dim_workspaces') }} as workspace
join {{ ref('stg_workspaces') }} as staged
    on workspace.source_row_id = staged.source_row_id
where workspace.workspace_id is distinct from staged.workspace_id
    or workspace.created_at is distinct from staged.created_at
    or workspace.deleted_at is distinct from staged.deleted_at
