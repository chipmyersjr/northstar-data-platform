{{ config(materialized='table', schema='canonical', contract={'enforced': true}) }}

select
    workspace.workspace_id,
    customer.customer_id,
    case
        when customer.customer_id is not null then 'resolved'
        else 'unresolved_customer'
    end as resolution_status
from {{ ref('dim_workspaces') }} as workspace
left join {{ ref('stg_workspaces') }} as staged
    on workspace.workspace_id = staged.workspace_id
left join {{ ref('dim_customer') }} as customer
    on staged.crm_account_ref = customer.customer_id
