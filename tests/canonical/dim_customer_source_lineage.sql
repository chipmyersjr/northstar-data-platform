-- Checks that each customer's ID matches the staging account identified by its source-row reference.
select customer.source_row_id
from {{ ref('dim_customer') }} as customer
join {{ ref('stg_accounts') }} as account
    on customer.source_row_id = account.source_row_id
where customer.customer_id is distinct from account.account_id
