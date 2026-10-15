-- Checks that restricted PII columns are absent from the canonical customer table.
{% set customers = ref('dim_customer') %}

select column_name
from information_schema.columns
where table_schema = '{{ customers.schema }}'
    and table_name = '{{ customers.identifier }}'
    and lower(column_name) in ('primary_contact_email', 'account_notes')
