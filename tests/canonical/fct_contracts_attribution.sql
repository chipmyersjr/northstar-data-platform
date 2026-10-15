-- Checks that each contract's customer and resolution status match its staging account reference.
select contract.source_row_id
from {{ ref('fct_contracts') }} as contract
left join {{ ref('stg_contracts') }} as staged
    on contract.source_row_id = staged.source_row_id
left join {{ ref('dim_customer') }} as customer
    on staged.account_id = customer.customer_id
where contract.customer_id is distinct from customer.customer_id
    or contract.resolution_status is distinct from case
        when customer.customer_id is not null then 'resolved'
        else 'unresolved_customer'
    end
