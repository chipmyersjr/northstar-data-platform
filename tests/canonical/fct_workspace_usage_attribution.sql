-- Checks all four attribution outcomes and ensures only resolved usage has the mapped customer ID.
select usage.source_row_id
from {{ ref('fct_workspace_usage') }} as usage
left join {{ ref('map_customer_workspaces') }} as mapping
    on usage.workspace_id = mapping.workspace_id
where usage.resolution_status is distinct from case
        when usage.workspace_id is null then 'missing_workspace'
        when mapping.workspace_id is null then 'unknown_workspace'
        when mapping.resolution_status = 'resolved' then 'resolved'
        else 'unresolved_customer'
    end
    or usage.customer_id is distinct from case
        when mapping.resolution_status = 'resolved' then mapping.customer_id
    end
