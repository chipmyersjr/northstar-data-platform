-- Checks that workspace names are absent from the canonical workspace table.
{% set workspaces = ref('dim_workspaces') %}

select column_name
from information_schema.columns
where table_schema = '{{ workspaces.schema }}'
    and table_name = '{{ workspaces.identifier }}'
    and lower(column_name) = 'workspace_name'
