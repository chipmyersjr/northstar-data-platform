-- Checks that customer ownership and resolution status match each workspace's staging customer reference.
select mapping.workspace_id
from {{ ref('map_customer_workspaces') }} as mapping
left join {{ ref('stg_workspaces') }} as staged
    on mapping.workspace_id = staged.workspace_id
left join {{ ref('dim_customer') }} as customer
    on staged.crm_account_ref = customer.customer_id
where mapping.customer_id is distinct from customer.customer_id
    or mapping.resolution_status is distinct from case
        when customer.customer_id is not null then 'resolved'
        else 'unresolved_customer'
    end
