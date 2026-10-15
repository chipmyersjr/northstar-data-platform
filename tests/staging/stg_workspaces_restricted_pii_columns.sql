-- Checks that sensitive workspace names are absent from the staging workspaces table.
{% set workspaces = ref('stg_workspaces') %}

select column_name
from information_schema.columns
where table_schema = '{{ workspaces.schema }}'
    and table_name = '{{ workspaces.identifier }}'
    and lower(column_name) = 'workspace_name'
