-- Checks that every canonical workspace has a mapping, including missing or unknown customer references.
select workspace.workspace_id
from {{ ref('dim_workspaces') }} as workspace
left join {{ ref('map_customer_workspaces') }} as mapping
    on workspace.workspace_id = mapping.workspace_id
where mapping.workspace_id is null
