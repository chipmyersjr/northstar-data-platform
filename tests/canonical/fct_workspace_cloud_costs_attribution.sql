-- Checks all four attribution outcomes and ensures only resolved charges have the mapped customer ID.
select cost.source_row_id
from {{ ref('fct_workspace_cloud_costs') }} as cost
left join {{ ref('map_customer_workspaces') }} as mapping
    on cost.workspace_id = mapping.workspace_id
where cost.resolution_status is distinct from case
        when cost.workspace_id is null then 'missing_workspace'
        when mapping.workspace_id is null then 'unknown_workspace'
        when mapping.resolution_status = 'resolved' then 'resolved'
        else 'unresolved_customer'
    end
    or cost.customer_id is distinct from case
        when mapping.resolution_status = 'resolved' then mapping.customer_id
    end
