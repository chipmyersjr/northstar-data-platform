-- Checks that workspace names, contact emails, and account notes are absent from the mapping table.
{% set mapping = ref('map_customer_workspaces') %}

select column_name
from information_schema.columns
where table_schema = '{{ mapping.schema }}'
    and table_name = '{{ mapping.identifier }}'
    and lower(column_name) in ('workspace_name', 'primary_contact_email', 'account_notes')
