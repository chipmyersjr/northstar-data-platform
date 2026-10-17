-- Checks that restricted PII columns are absent from the canonical cloud-cost table.
{% set costs = ref('fct_workspace_cloud_costs') %}

select column_name
from information_schema.columns
where table_schema = '{{ costs.schema }}'
    and table_name = '{{ costs.identifier }}'
    and lower(column_name) in ('primary_contact_email', 'account_notes', 'workspace_name')
