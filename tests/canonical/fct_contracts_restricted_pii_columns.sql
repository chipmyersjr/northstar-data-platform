-- Checks that restricted PII columns are absent from the canonical contract table.
{% set contracts = ref('fct_contracts') %}

select column_name
from information_schema.columns
where table_schema = '{{ contracts.schema }}'
    and table_name = '{{ contracts.identifier }}'
    and lower(column_name) in ('primary_contact_email', 'account_notes', 'workspace_name')
