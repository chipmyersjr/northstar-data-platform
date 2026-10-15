-- Checks that restricted PII columns are absent from the staging accounts table.
{% set accounts = ref('stg_accounts') %}

select column_name
from information_schema.columns
where table_schema = '{{ accounts.schema }}'
  and table_name = '{{ accounts.identifier }}'
  and lower(column_name) in (
      'primary_contact_email',
      'account_notes',
      'workspace_name'
  )
