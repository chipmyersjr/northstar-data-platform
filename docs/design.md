# Northstar Warehouse Design

## 1. Final Customer Reporting View

`published.customer_monthly_metrics` is a **dbt table** with one row per customer per eligible reporting month, including historical months. A customer-month is published only when customer attribution is resolved, subscription metrics are reliable, and usage and cost data are complete for all active workspaces. Incomplete customer-months are excluded without affecting other customers.

Annualized subscription value is based on contracts effective at month-end, while usage, cloud costs, and estimated revenue reflect activity during the month. The `reporting_month` column identifies that period, and all monetary values are in USD.

Both published tables are fully rebuilt on each run. This keeps the pipeline simple and repeatable for the current dataset. As data volume grows, dbt supports moving to incremental processing without changing the published schema or metric definitions, provided updates and historical corrections are handled correctly.

```sql
CREATE TABLE published.customer_monthly_metrics (
    customer_id VARCHAR NOT NULL,
    customer_name VARCHAR,
    reporting_month DATE NOT NULL,
    annualized_subscription_value_usd DECIMAL(18,2),
    monthly_subscription_revenue_usd DECIMAL(18,2),
    product_usage_active_users BIGINT,
    product_usage_api_calls BIGINT,
    cloud_cost_usd DECIMAL(18,2),
    gross_margin DECIMAL(18,4)
);
```

| Column | Definition |
| --- | --- |
| `customer_id` | Customer ID from the normalized `accounts.account_id`. |
| `customer_name` | Customer name from `accounts.account_name`. |
| `reporting_month` | First day of the reporting month. Together with `customer_id`, uniquely identifies each row. |
| `annualized_subscription_value_usd` | Annualized value of contracts active at month-end. Monthly amounts are multiplied by 12; annual amounts are used as-is. Contracts that ended before month-end or start afterward are excluded. |
| `monthly_subscription_revenue_usd` | Estimated subscription revenue for the month, prorated based on the number of active service days. |
| `product_usage_active_users` | Sum of active users across the customer's workspaces for the month. Users active in multiple workspaces may be counted more than once. |
| `product_usage_api_calls` | Total API calls across the customer's workspaces for the month. |
| `cloud_cost_usd` | Total compute and storage costs attributed to the customer's workspaces for the month. Unallocated costs are tracked in `published.monthly_data_quality_exceptions`. |
| `gross_margin` | Percentage of estimated subscription revenue remaining after cloud costs: (`monthly_subscription_revenue_usd` − `cloud_cost_usd`) / `monthly_subscription_revenue_usd` × 100. Null when revenue is zero or required inputs are unknown. Other costs of revenue are not included. |

**Metric rules**

- Keep contact emails and account notes out of both published tables to protect PII.
- **Monthly subscription revenue** is estimated from each contract's annualized value divided by 12, prorated for the days it provided service during the reporting month. Include contracts that ended during the month, even if they are no longer active at month-end.
- Prorate partial-month starts and ends using inclusive service dates. Count days from the later of the contract start or month-start through the earlier of the contract end or month-end. Treat a missing contract end date as month-end. Sum the contract amounts by customer, then round to cents.
- Group metrics by customer and reporting month. All four business questions can be answered directly from `published.customer_monthly_metrics`, without joining to the exceptions table.
- Start reporting each customer from their earliest reliable contract start or associated workspace creation date. Continue reporting after subscriptions end or are cancelled. Do not use account `updated_at` as a creation date.
- **Customer-month eligibility:** Publish a completed month only when subscription metrics are reliable, customer attribution is resolved, and every known workspace active during that month has valid usage and cloud-cost coverage. A workspace is active if it was created by month-end and was not deleted before month-start.
- If a customer-month fails validation, exclude it and record the reason in `published.monthly_data_quality_exceptions`. Missing usage or cost data is not treated as zero, although confirmed zero activity or no eligible contracts may produce zero values. Gross margin is null when revenue is zero or cannot be calculated reliably.
- Keep unresolved mappings and unallocated costs visible without assigning them to customers arbitrarily or blocking unrelated customer-months.
- **Metric limitations:** Annualized subscription value is a month-end contract snapshot, while monthly subscription revenue is a prorated estimate, not recognized accounting revenue. Gross margin includes only the available cloud costs and is not a GAAP gross margin measure.
- **Aggregation limitations:** Customer-month values should not be treated as complete company-wide totals. Unallocated costs, unresolved mappings, and excluded customer-months may leave activity unrepresented.
- Do not sum annualized subscription value across months or sum or directly average gross-margin percentages. Active-user counts may overlap across workspaces or customers and do not represent distinct company-wide users. Company-level reporting would need its own aggregation and reconciliation rules.

`published.monthly_data_quality_exceptions` is a **dbt table**, retaining exceptions for both published and unpublished customer-months.

```sql
CREATE TABLE published.monthly_data_quality_exceptions (
    reporting_month DATE,
    source_table VARCHAR NOT NULL,
    issue_category VARCHAR NOT NULL,
    issue_reason VARCHAR NOT NULL,
    workspace_id VARCHAR,
    customer_id VARCHAR,
    source_row_id BIGINT,
    excluded_financial_amount_usd DECIMAL(18,2),
    excluded_active_users BIGINT,
    excluded_api_calls BIGINT
);
```

- `reporting_month` identifies the affected month; retain null when an invalid source date prevents determining it. Source table, available identifiers, and source-row ID support tracing the exception; missing-record exceptions have no source-row ID.
- Use `completeness` / `missing_usage` or `missing_cloud_cost` for expected workspace coverage gaps; `mapping` / `unresolved_customer` or `unknown_workspace` for unresolved identities; and `quarantine` / the actual specific staging or canonical rejection reason, not a generic `quarantined_record` label. Costs with no workspace ID use `mapping` / `missing_workspace`.
- Retain excluded customer-months with their specific reasons, excluded financial amounts and usage counts where applicable, and unresolved usage and unallocated costs. Null means unavailable or not applicable, not zero; completeness exceptions must not invent missing amounts or counts.



## 2. Build, Recovery, and Verification

### 2.1 Build Execution and Example Queries

- `make build` initializes a queryable DuckDB warehouse from a clean checkout, builds all dbt models in dependency order, and runs the tests. Verify this with no existing warehouse: all expected tables must be created, required tests must pass, and published metrics must be queryable.
- `make queries` displays four labeled, single-`SELECT` examples against `published.customer_monthly_metrics`, without joins, data cleaning, or filtering unresolved records:
  1. Annualized subscription value by customer and reporting month.
  2. Product usage (active users and API calls) by customer and reporting month.
  3. Cloud cost by customer and reporting month.
  4. Gross margin by customer and reporting month.
- Document both commands and required prerequisites, including the supplied raw database, in the README so reviewers can reproduce the results.

### 2.2 Idempotency and Recovery

- Run the complete build twice against unchanged raw inputs and verify identical schemas, row counts, and table contents across all downstream tables.
- Delete or truncate a downstream table, rerun the complete build, and verify correct restoration. Full rebuilds must not depend on previously materialized downstream contents; raw inputs remain unchanged.

### 2.3 Source-Row Accounting

- Verify every raw source row appears exactly once in staging or quarantine, and every accepted staging row has exactly one canonical selection outcome: selected, duplicate/superseded audit, or canonical quarantine.
- Trace each record by source table and `source_row_id` through its outcomes and any applicable published exception, preserving explicit rejection, duplicate/supersession, and unresolved-attribution reasons. Attribution audit entries must not count as additional source records.

### 2.4 Data-Quality Verification and Reconciliation

- Run uniqueness, non-null, relationship, accepted-value, and business-rule tests. Verify metric calculations, customer-month completeness, and absence of restricted PII.
- Reconcile raw records and financial/usage totals through staging or quarantine, canonical selection, duplicate/superseded audit, or canonical quarantine, intermediate metrics, and published outputs. Explain differences from unresolved attribution and excluded customer-months without double-counting. Reconcile derived metrics through their eligibility, annualization, and proration rules; ASV need not equal raw amounts.
- Test representative scenarios: duplicate records, null selection timestamps in repeated groups, identical/conflicting latest-timestamp ties, missing workspace mappings, missing monthly usage or costs, incorrect financial totals, and restricted PII exposure. Verify the expected disposition or build failure for each.

### 2.5 Publication Safeguards

- Fail `dbt build` on integrity (including required-field, uniqueness, and relationship checks), calculation, lineage, reconciliation, or PII-protection violations. Treat published tables as current only after a successful build; failed builds may leave stale or partially rebuilt tables available.
- Expected source-data exceptions—staging/canonical quarantined records and unresolved attribution—remain visible without automatically failing the build.
- Exclude only customer-months with incomplete workspace usage, cloud-cost coverage, or unreliable subscription metrics. Verify every exclusion has a specific reason in `published.monthly_data_quality_exceptions` and unaffected valid customer-months remain publishable.

## 3. Transformation Pipeline

```text
┌────────────────────────────────────────────┐
│                RAW SOURCES                 │
│      Accounts, Contracts, Workspaces,      │
│             Usage, Cloud Costs             │
└────────────────────────────────────────────┘
                      ↓
┌────────────────────────────────────────────┐
│                  STAGING                   │
│        Normalize IDs, parse types,         │
│              validate records              │
└────────────────────────────────────────────┘
                      ├──────────────────────────────────────────────────┐
                      ↓                                                  ↓
┌────────────────────────────────────────────┐    ┌──────────────────────────────────────────────┐
│                 CANONICAL                  │    │                 DATA QUALITY                 │
│ Customer/workspace dimensions and mapping, │    │  Quarantined records, unresolved mappings,   │
│      contract, usage, and cost facts       │    │                audit records                 │
└────────────────────────────────────────────┘    └──────────────────────────────────────────────┘
                      ↓                                                  ↓
┌────────────────────────────────────────────┐    ┌──────────────────────────────────────────────┐
│                INTERMEDIATE                │    │                  EXCEPTIONS                  │
│        Monthly subscription, usage,        │    │     Missing coverage, unallocated costs,     │
│           and cloud-cost metrics           │    │               rejected records               │
└────────────────────────────────────────────┘    └──────────────────────────────────────────────┘
                      ↓                                                  ↓
┌────────────────────────────────────────────┐    ┌──────────────────────────────────────────────┐
│        PUBLISHED CUSTOMER REPORTING        │    │      PUBLISHED DATA-QUALITY EXCEPTIONS       │
│           Valid customer-months            │    │  published.monthly_data_quality_exceptions   │
│     published.customer_monthly_metrics     │    │                                              │
└────────────────────────────────────────────┘    └──────────────────────────────────────────────┘
```

### 3.1 Raw Sources

#### `raw.accounts` — CRM customers

| Field | Meaning |
| --- | --- |
| `account_id` | CRM customer identifier. |
| `account_name` | Customer name displayed in the final report. |
| `segment` | Customer category: Enterprise, Mid-market, or SMB. |
| `region` | Customer region: NA, EU, or APAC. |
| `primary_contact_email` | Contact email; sensitive. |
| `account_notes` | Free-text CRM notes; treat as sensitive. |
| `updated_at` | Account update timestamp stored as text. |

**Notes**

- Keep contact emails and account notes in access-restricted raw storage. Do not expose them in analyst-accessible staging, canonical, intermediate, or published tables. Free-text fields may contain PII even when no email address is present.
- Normalize account IDs consistently across all sources.
- Treat `updated_at` as the account's last-update timestamp, not its creation date. Rebuild downstream account models from the full `raw.accounts` dataset on each run, leaving the raw source unchanged.

#### `raw.contracts_batch1` — Subscription contracts

| Field | Meaning |
| --- | --- |
| `contract_id` | Subscription contract identifier. |
| `account_id` | CRM customer associated with the contract. |
| `plan` | Subscription plan: Enterprise, Growth, or Starter. |
| `billing_period` | Billing frequency: annual or monthly. |
| `recurring_amount_usd` | Recurring amount in USD for the billing period. |
| `starts_on` | Contract start date. |
| `ends_on` | Contract end date; missing means open-ended. |
| `status` | Contract status: active or cancelled. |
| `source_batch` | Identifier of the source extract. |
| `extracted_at` | Timestamp when the extract was produced. |

Notes:

- Trim whitespace from contract and customer IDs and convert them to uppercase. Normalize billing periods and statuses to lowercase.
- Parse amounts as decimals, service dates as dates, and extraction timestamps with timezone information. Validate amounts and date ranges before using them in calculations.
- Use contract service dates, not status alone, to determine eligibility. Annualized subscription value includes contracts active at month-end, while monthly subscription revenue includes all contracts providing service during the month, including cancelled contracts through their end date.

#### `raw.workspaces` — Product workspaces

| Field | Meaning |
| --- | --- |
| `workspace_id` | Product workspace identifier. |
| `workspace_name` | Workspace display name. |
| `crm_account_ref` | Account identifier linking the workspace to a CRM customer. |
| `created_at` | Workspace creation date stored as text. |
| `deleted_at` | Workspace deletion date; missing means no recorded deletion. |

Notes:

- Customer references contain lowercase and trailing-space differences, including `a-101` and `A-102 `.
- Some customer references are missing or do not match an account in `raw.accounts`, including W-307 (`A-999`) and W-308 (null).
- Creation and deletion dates are stored as text; a missing deletion date means no deletion is recorded.
- Workspace names are free text and may contain personal information; treat them as sensitive and keep them in access-restricted raw storage.

#### `raw.usage_batch1` — Monthly workspace usage

| Field | Meaning |
| --- | --- |
| `usage_id` | Usage record identifier. |
| `workspace_id` | Workspace associated with the usage. |
| `usage_month` | Reporting month, represented by its first day. |
| `active_users` | Workspace active-user count for the month. |
| `api_calls` | Workspace API-call count for the month. |
| `source_batch` | Identifier of the source extract. |
| `extracted_at` | Timestamp when the extract was produced. |

Notes:

- Usage and workspace identifiers are stored as text.
- Reporting months and extraction timestamps are stored as text and require date/timestamp parsing.
- Active-user and API-call counts are stored as text rather than numeric types.
- The provided extract contains April 2026 usage records for W-300 through W-308.
- Active-user counts are aggregated at workspace-month grain; the same person may be counted in multiple workspaces.

#### `raw.cloud_costs` — Monthly cloud costs

| Field | Meaning |
| --- | --- |
| `cost_id` | Cloud-cost record identifier. |
| `workspace_id` | Workspace associated with the cost; may be missing. |
| `usage_month` | Month the cost belongs to, represented by its first day. |
| `compute_cost_usd` | Compute cost in USD. |
| `storage_cost_usd` | Storage cost in USD. |
| `source_batch` | Identifier of the source extract. |
| `extracted_at` | Timestamp when the extract was produced. |

Notes:

- Cost and workspace identifiers are stored as text; workspace identifiers may be missing or reference unknown workspaces.
- Reporting months and extraction timestamps are stored as text. The reporting month identifies when costs were incurred, not when the extract was produced.
- Compute and storage costs are stored as text rather than decimal types.
- The provided extract includes K-508 with no workspace ID and K-509 referencing unknown workspace W-999.
- Cost records contain separate compute and storage amounts; multiple cost records may belong to the same workspace-month.



### 3.2 Staging

**Shared validation rules**

- Quarantine records include `source_table`, `source_row_id`, and `rejection_reasons`, along with only the safe fields needed for investigation and reconciliation. The `source_row_id` must trace back to the original record, even when its business ID is missing or invalid.
- Missing or invalid optional `updated_at` and `extracted_at` values are set to null rather than quarantined.
- **PII protection and residual risks:** Contact emails, account notes, and workspace names are treated as sensitive and excluded from downstream models, including quarantine and audit tables. Raw data access must be restricted. Personal information may still appear in customer names or identifiers, or be exposed through logs, debugging, or direct raw database access.

#### `staging.stg_accounts`

dbt **table**, rebuilt each run. `staging.quarantine_accounts` is also rebuilt each run and follows the quarantine rules below. One row per accepted source record. `source_row_id` is an audit key generated from the raw row reference.

DuckDB `rowid` provides source-row identity for the supplied, unchanged raw table; it is not guaranteed to remain stable if the raw table is recreated.

```sql
CREATE TABLE staging.stg_accounts (
    source_row_id BIGINT NOT NULL,
    account_id VARCHAR NOT NULL,
    account_name VARCHAR NOT NULL,
    segment VARCHAR,
    region VARCHAR,
    updated_at TIMESTAMP WITH TIME ZONE
);
```

| Source column | Staging column | Transformation |
| --- | --- | --- |
| Internal DuckDB `rowid` | `source_row_id` | Preserve the raw row reference for this supplied database. |
| `account_id` | `account_id` | Trim whitespace, convert to uppercase, and treat empty values as null. |
| `account_name` | `account_name` | Trim whitespace and treat empty values as null. |
| `segment` | `segment` | Trim whitespace and treat empty values as null. |
| `region` | `region` | Trim whitespace, convert to uppercase, and treat empty values as null. |
| `primary_contact_email` | — | Excluded: PII. |
| `account_notes` | — | Excluded: PII. |
| `updated_at` | `updated_at` | Parse as a timezone-aware timestamp; invalid or empty values become null. |

**Row validation**

- Missing account ID or name: send the record to `staging.quarantine_accounts`, retaining `source_row_id` and a reason. Exclude emails and notes from both outputs.

**dbt tests and publication**

- `not_null`: `source_row_id`, `account_id`, `account_name`; `unique`: `source_row_id`.
- Row accounting: raw count = staging count + quarantine count. Each raw `source_row_id` must appear in exactly one output. Unexplained loss or duplication fails validation.
- Fail `dbt build` when accepted records violate required-field or source-row uniqueness checks, or when row accounting fails. Dependent models selected in the same build are skipped when their upstream tests fail. Previously built published tables may remain available, but are not guaranteed to be current.

#### `staging.stg_contracts`

dbt **table**, rebuilt each run. `staging.quarantine_contracts` is also rebuilt each run and follows the quarantine rules below. One row per accepted record from `raw.contracts_batch1`. `source_row_id` is the logical audit key within this source.

DuckDB `rowid` provides source-row identity for the supplied, unchanged raw table; it is not guaranteed to remain stable if the raw table is recreated.

```sql
CREATE TABLE staging.stg_contracts (
    source_row_id BIGINT NOT NULL,
    contract_id VARCHAR NOT NULL,
    account_id VARCHAR,
    plan VARCHAR,
    billing_period VARCHAR NOT NULL,
    recurring_amount_usd DECIMAL(18,2) NOT NULL,
    starts_on DATE NOT NULL,
    ends_on DATE,
    status VARCHAR NOT NULL,
    source_batch VARCHAR,
    extracted_at TIMESTAMP WITH TIME ZONE
);
```

| Source column | Staging column | Transformation |
| --- | --- | --- |
| Internal DuckDB `rowid` | `source_row_id` | Preserve the raw DuckDB row reference. |
| `contract_id` | `contract_id` | Trim whitespace, convert to uppercase, and treat empty values as null. |
| `account_id` | `account_id` | Trim whitespace, convert to uppercase, and treat empty values as null. |
| `plan` | `plan` | Trim whitespace and treat empty values as null. |
| `billing_period` | `billing_period` | Trim whitespace, convert to lowercase, and treat empty values as null. |
| `recurring_amount_usd` | `recurring_amount_usd` | Parse as a decimal with two fractional digits; invalid or empty values become null. |
| `starts_on` | `starts_on` | Parse as a date; invalid or empty values become null. |
| `ends_on` | `ends_on` | Parse as a date; empty values become null, while invalid nonempty values are flagged. |
| `status` | `status` | Trim whitespace, convert to lowercase, and treat empty values as null. |
| `source_batch` | `source_batch` | Preserve the original value. |
| `extracted_at` | `extracted_at` | Parse as a timezone-aware timestamp; invalid or empty values become null. |

**Row validation**

- Send missing contract IDs, invalid/negative amounts, invalid service dates, end dates before start dates, and cancelled contracts without end dates to `staging.quarantine_contracts`, with the source-row reference and reason. A blank end date is valid for active contracts; an unparseable end date is not.
- Accept `annual`/`monthly` billing periods and `active`/`cancelled` statuses; quarantine other values because their metric treatment is undefined.
- Keep missing or unmatched account references for explicit unresolved mapping downstream; do not discard the contract.

**dbt tests and validations**

- `not_null`: `source_row_id`, `contract_id`, `billing_period`, `recurring_amount_usd`, `starts_on`, `status`; `unique`: `source_row_id`.
- `accepted_values`: billing period = annual/monthly; status = active/cancelled.
- Custom checks: nonnegative amount, valid service-date order, and an end date for cancelled contracts.
- Raw count = staging count + quarantine count; each raw row reference appears exactly once across the outputs.
- Fail `dbt build` when accepted records violate required-field, accepted-value, service-date, or source-row uniqueness checks, or when row accounting fails. Dependent models selected in the same build are skipped when their upstream tests fail. Previously built published tables may remain available, but are not guaranteed to be current. Quarantined records alone do not fail the build.

#### `staging.stg_workspaces`

dbt **table**, rebuilt each run. `staging.quarantine_workspaces` is also rebuilt each run and follows the quarantine rules below. One row per accepted record from `raw.workspaces`; `source_row_id` is the logical audit key within this source.

DuckDB `rowid` provides source-row identity for the supplied, unchanged raw table; it is not guaranteed to remain stable if the raw table is recreated.

```sql
CREATE TABLE staging.stg_workspaces (
    source_row_id BIGINT NOT NULL,
    workspace_id VARCHAR NOT NULL,
    crm_account_ref VARCHAR,
    created_at DATE NOT NULL,
    deleted_at DATE
);
```

| Source column | Staging column | Transformation |
| --- | --- | --- |
| Internal DuckDB `rowid` | `source_row_id` | Preserve the raw DuckDB row reference. |
| `workspace_id` | `workspace_id` | Trim whitespace, convert to uppercase, and treat empty values as null. |
| `workspace_name` | — | Excluded: free text may contain PII. |
| `crm_account_ref` | `crm_account_ref` | Trim whitespace, convert to uppercase, and treat empty values as null. |
| `created_at` | `created_at` | Parse as a date; invalid or empty values become null. |
| `deleted_at` | `deleted_at` | Parse as a date; empty values become null, while invalid nonempty values are flagged. |

**Row validation**

- Send missing workspace IDs, invalid creation/deletion dates, and deletion dates before creation dates to `staging.quarantine_workspaces`, with the source-row reference and reason. A blank deletion date is valid; an unparseable date is not.
- Keep missing or unmatched customer references for explicit unresolved mapping downstream.
- Exclude workspace names from both staging and quarantine.

**dbt tests and validations**

- `not_null`: `source_row_id`, `workspace_id`, `created_at`; `unique`: `source_row_id`.
- Custom check: `deleted_at` is null or on/after `created_at`.
- Raw count = staging count + quarantine count; each raw row reference appears exactly once across the outputs.
- Fail `dbt build` when accepted records violate required-field, workspace lifecycle-date, or source-row uniqueness checks, or when row accounting fails. Dependent models selected in the same build are skipped when their upstream tests fail. Previously built published tables may remain available, but are not guaranteed to be current. Quarantined records alone do not fail the build.

#### `staging.stg_usage`

dbt **table**, rebuilt each run. `staging.quarantine_usage` is also rebuilt each run and follows the quarantine rules below. One row per accepted record from `raw.usage_batch1`; `source_row_id` is the logical audit key within this source.

DuckDB `rowid` provides source-row identity for the supplied, unchanged raw table; it is not guaranteed to remain stable if the raw table is recreated.

```sql
CREATE TABLE staging.stg_usage (
    source_row_id BIGINT NOT NULL,
    usage_id VARCHAR NOT NULL,
    workspace_id VARCHAR,
    usage_month DATE NOT NULL,
    active_users BIGINT NOT NULL,
    api_calls BIGINT NOT NULL,
    source_batch VARCHAR,
    extracted_at TIMESTAMP WITH TIME ZONE
);
```

| Source column | Staging column | Transformation |
| --- | --- | --- |
| Internal DuckDB `rowid` | `source_row_id` | Preserve the raw DuckDB row reference. |
| `usage_id` | `usage_id` | Trim whitespace, convert to uppercase, and treat empty values as null. |
| `workspace_id` | `workspace_id` | Trim whitespace, convert to uppercase, and treat empty values as null. |
| `usage_month` | `usage_month` | Parse as a date and normalize to the first day of the month; invalid or empty values become null. |
| `active_users` | `active_users` | Parse as a nonnegative whole number; reject fractional, invalid, or out-of-range values. |
| `api_calls` | `api_calls` | Parse as a nonnegative whole number; reject fractional, invalid, or out-of-range values. |
| `source_batch` | `source_batch` | Preserve the original value. |
| `extracted_at` | `extracted_at` | Parse as a timezone-aware timestamp; invalid or empty values become null. |

**Row validation**

- Send missing usage IDs, invalid months, and invalid/negative counts to `staging.quarantine_usage`, with the source-row reference and reason.
- Normalize valid `usage_month` dates to the first day of the month.
- Validate count values as nonnegative whole numbers before casting, so fractional values cannot be rounded into integers. Reject values exceeding `BIGINT` capacity.
- Keep missing or unmatched workspace references for explicit unresolved mapping downstream.

**dbt tests and validations**

- `not_null`: `source_row_id`, `usage_id`, `usage_month`, `active_users`, `api_calls`; `unique`: `source_row_id`.
- Custom checks: nonnegative counts and first-of-month `usage_month`.
- Raw count = staging count + quarantine count; each raw row reference appears exactly once across the outputs.
- Fail `dbt build` when accepted records violate required-field, usage-month, count-validity, or source-row uniqueness checks, or when row accounting fails. Dependent models selected in the same build are skipped when their upstream tests fail. Previously built published tables may remain available, but are not guaranteed to be current. Quarantined records alone do not fail the build.

#### `staging.stg_cloud_costs`

dbt **table**, rebuilt each run. `staging.quarantine_cloud_costs` is also rebuilt each run and follows the quarantine rules below. One row per accepted record from `raw.cloud_costs`; `source_row_id` is the logical audit key within this source.

DuckDB `rowid` provides source-row identity for the supplied, unchanged raw table; it is not guaranteed to remain stable if the raw table is recreated.

```sql
CREATE TABLE staging.stg_cloud_costs (
    source_row_id BIGINT NOT NULL,
    cost_id VARCHAR NOT NULL,
    workspace_id VARCHAR,
    usage_month DATE NOT NULL,
    compute_cost_usd DECIMAL(18,2) NOT NULL,
    storage_cost_usd DECIMAL(18,2) NOT NULL,
    source_batch VARCHAR,
    extracted_at TIMESTAMP WITH TIME ZONE
);
```

| Source column | Staging column | Transformation |
| --- | --- | --- |
| Internal DuckDB `rowid` | `source_row_id` | Preserve the raw DuckDB row reference. |
| `cost_id` | `cost_id` | Trim whitespace, convert to uppercase, and treat empty values as null. |
| `workspace_id` | `workspace_id` | Trim whitespace, convert to uppercase, and treat empty values as null. |
| `usage_month` | `usage_month` | Parse as a date and normalize to the first day of the month; invalid or empty values become null. |
| `compute_cost_usd` | `compute_cost_usd` | Parse as a decimal with two fractional digits; invalid or empty values become null. Reject values that cannot be represented exactly to two decimal places. |
| `storage_cost_usd` | `storage_cost_usd` | Parse as a decimal with two fractional digits; invalid or empty values become null. Reject values that cannot be represented exactly to two decimal places. |
| `source_batch` | `source_batch` | Preserve the original value. |
| `extracted_at` | `extracted_at` | Parse as a timezone-aware timestamp; invalid or empty values become null. |

**Row validation**

- Send missing cost IDs, invalid months, and invalid/negative cost amounts to `staging.quarantine_cloud_costs`, with the source-row reference and reason.
- Reject compute or storage costs with more than two nonzero decimal places rather than silently rounding them. Trailing zeros are permitted; for example, `12.340` is valid, but `12.345` is not.
- Normalize valid cost months to the first day of the month.
- Keep missing or unmatched workspace references for explicit unresolved mapping downstream.

**dbt tests and validations**

- `not_null`: `source_row_id`, `cost_id`, `usage_month`, `compute_cost_usd`, `storage_cost_usd`; `unique`: `source_row_id`.
- Custom checks: nonnegative compute/storage costs and first-of-month `usage_month`.
- Raw count = staging count + quarantine count; each raw row reference appears exactly once across the outputs.
- Fail `dbt build` when accepted records violate required-field, cost-validity, usage-month, or source-row uniqueness checks, or when row accounting fails. Dependent models selected in the same build are skipped when their upstream tests fail. Previously built published tables may remain available, but are not guaranteed to be current. Quarantined records alone do not fail the build.







### 3.3 Canonical Models

#### `canonical.dim_customer`

dbt **table**, rebuilt each run from `staging.stg_accounts`. One row per customer; `customer_id` is the logical primary key. This is the latest customer snapshot, not customer history.

```sql
CREATE TABLE canonical.dim_customer (
    customer_id VARCHAR NOT NULL,
    customer_name VARCHAR NOT NULL,
    segment VARCHAR,
    region VARCHAR,
    updated_at TIMESTAMP WITH TIME ZONE,
    source_row_id BIGINT NOT NULL
);
```

**Transformation rules**

- Rename `account_id` to `customer_id` and `account_name` to `customer_name`. Group records by normalized `customer_id`, not customer name.
- For each normalized `customer_id`, use `updated_at` to select records. Select a single record even with a null timestamp; otherwise select the latest when all timestamps are present. Quarantine the entire group if any timestamp is null (`missing_selection_timestamp`) or latest-timestamp ties have conflicting business attributes (`conflicting_latest_records`). For identical latest ties, including matching null attributes, select the smallest `source_row_id` and audit the others as duplicates; never use it to resolve missing timestamps or conflicting attributes. Keep the selected customer name, segment, region, timestamp, and source-row ID.
- Compare customer name, segment, and region as business attributes, excluding selection timestamps, batch metadata, and source-row IDs. Rebuild `canonical.quarantine_customers` each run with every contributing record’s `source_table`, `source_row_id`, normalized `customer_id`, and `rejection_reasons`, plus safe attribution, period, amount, or count fields needed for reconciliation. Exclude restricted PII; ambiguous groups have no selected or duplicate/superseded audit outcome.
- Rebuild `canonical.customer_record_audit` on each run to track unselected records from nonquarantined groups. Include `source_row_id`, `customer_id`, `disposition`, and `selected_source_row_id`.
- Mark records as `duplicate` when their customer name, segment, and region match the selected record, including null values. Otherwise, mark them as `superseded`.
- Keep emails, notes, and other sensitive fields out of audit and canonical quarantine outputs.

**dbt tests and validations**

- Verify canonical quarantine reasons, source lineage, and PII exclusion against the rules above.
- `not_null`: `customer_id`, `customer_name`, `source_row_id`; `unique`: `customer_id` and `source_row_id`.
- `relationships`: selected `source_row_id` references `staging.stg_accounts`. Custom lineage check: the selected staging `account_id` equals canonical `customer_id`.
- Verify every staged account row appears exactly once as selected, in `canonical.customer_record_audit`, or in `canonical.quarantine_customers`, with no missing or double-counted rows.
- Audit disposition must be `superseded` or `duplicate`, consistent with the attribute comparison above. Each audit record’s `selected_source_row_id` must reference the selected canonical row for the same customer. Verify selection or whole-group quarantine follows the selection rules above.
- Fail `dbt build` when required-field, uniqueness, selection, lineage, audit-integrity, or row-accounting tests fail. Expected canonical quarantine alone does not fail the build. Dependent models selected in the same build are skipped when upstream tests fail. Previously built published tables may remain available but may be stale.

#### `canonical.dim_workspaces`

dbt **table**, rebuilt each run; one row per normalized `workspace_id` (logical primary key). All columns come directly from the selected `staging.stg_workspaces` record.

```sql
CREATE TABLE canonical.dim_workspaces (
    workspace_id VARCHAR NOT NULL,
    created_at DATE NOT NULL,
    deleted_at DATE,
    source_row_id BIGINT NOT NULL
);
```

**Transformation rules**

- Keep one record per normalized `workspace_id`, selecting the record with the largest `source_row_id` as the deterministic representative.
- Rebuild the supporting dbt table `canonical.workspace_record_audit` each run. For every unselected staged workspace row, retain `source_row_id`, normalized `workspace_id`, `disposition`, and `selected_source_row_id`. Use `duplicate` when creation and deletion dates match the selected record, treating two null deletion dates as equal; otherwise use `superseded`.

**dbt tests and validations**

- `not_null`: `workspace_id`, `created_at`, `source_row_id`; `unique`: `workspace_id` and `source_row_id`.
- `relationships`: selected `source_row_id` references `staging.stg_workspaces`. Custom lineage check: the selected staging row has the same workspace ID, creation date, and deletion date as the canonical row.
- Check that `deleted_at` is null or on/after `created_at`.
- Verify every staged workspace row appears exactly once, either in `canonical.dim_workspaces` or `canonical.workspace_record_audit`, with no missing or double-counted rows.
- Audit disposition must be `duplicate` or `superseded`, consistent with the date comparison above. Each audit record’s `selected_source_row_id` must reference the selected canonical row for the same workspace. Verify the latest record was selected using the largest `source_row_id` for that workspace.
- Fail `dbt build` when required-field, uniqueness, lineage, lifecycle, audit-integrity, or row-accounting tests fail. Dependent models selected in the same build are skipped when upstream tests fail. Previously built published tables may remain available but may be stale.


#### `canonical.map_customer_workspaces`

dbt **table**, rebuilt each run from `canonical.dim_workspaces`, `canonical.dim_customer`, and `staging.stg_workspaces`. One row per workspace; `workspace_id` is the logical primary key. A customer can own multiple workspaces; a workspace has at most one resolved customer.

```sql
CREATE TABLE canonical.map_customer_workspaces (
    workspace_id VARCHAR NOT NULL,
    customer_id VARCHAR,
    resolution_status VARCHAR NOT NULL
);
```

**Transformation rules**

- Use `canonical.dim_workspaces` as the workspace list. Check all matching `staging.stg_workspaces` records for their normalized `crm_account_ref` values, ignoring blanks when counting distinct references.
- **Resolved:** If there is exactly one distinct nonblank customer reference and it matches `canonical.dim_customer.customer_id`, assign that customer and set `resolution_status` to `resolved`.
- **Unresolved:** Leave `customer_id` null and set `resolution_status` to `unresolved_customer` when:
  - **Missing customer:** All references are blank or null.
  - **Unknown customer:** One distinct reference exists but does not match a canonical customer.
  - **Conflicting customer:** Multiple distinct references exist, even if some are valid. Never choose an owner arbitrarily.
- Rebuild `canonical.workspace_mapping_audit` each run to track unresolved mappings. Include `workspace_id`, `source_row_id`, nullable normalized `crm_account_ref`, and `issue_reason` (`missing_customer`, `unknown_customer`, or `conflicting_customer`).
- For missing or unknown mappings, retain the relevant staging source rows. For conflicts, retain every contributing staging row.
- Do not create a separate mapping quarantine table or include sensitive fields such as workspace names, emails, or notes. Unresolved mappings do not automatically fail `dbt build`.

**dbt tests and validations**

- `not_null`: `workspace_id`, `resolution_status`; `unique`: `workspace_id`; `accepted_values`: status = resolved/unresolved_customer.
- `relationships`: workspace ID references `dim_workspaces`; nonnull customer ID references `dim_customer`. Resolved rows require a customer ID; unresolved rows require null.
- Every canonical workspace appears exactly once. Verify assignments against all corresponding `staging.stg_workspaces` records and the resolution rules above.
- Every unresolved workspace has audit records with the correct reason and source-row references. Each audit record references an unresolved workspace and an actual staging row belonging to it; accepted reasons are `missing_customer`, `unknown_customer`, and `conflicting_customer`.
- Fail `dbt build` when mapping integrity, required-field, uniqueness, relationship, resolution, or audit-consistency tests fail. Dependent models selected in the same build are skipped when upstream tests fail. Previously built published tables may remain available but may be stale.

#### `canonical.fct_contracts`

dbt **table**, rebuilt each run from `staging.stg_contracts` and `canonical.dim_customer`. One row per normalized `contract_id` (logical primary key), retaining the latest contract record for both month-end subscription value and reporting-month revenue.

```sql
CREATE TABLE canonical.fct_contracts (
    contract_id VARCHAR NOT NULL,
    customer_id VARCHAR,
    resolution_status VARCHAR NOT NULL,
    plan VARCHAR,
    billing_period VARCHAR NOT NULL,
    recurring_amount_usd DECIMAL(18,2) NOT NULL,
    starts_on DATE NOT NULL,
    ends_on DATE,
    status VARCHAR NOT NULL,
    source_batch VARCHAR,
    extracted_at TIMESTAMP WITH TIME ZONE,
    source_row_id BIGINT NOT NULL
);
```

**Transformation rules**

- For each normalized `contract_id`, use `extracted_at` to select records. Select a single record even with a null timestamp; otherwise select the latest when all timestamps are present. Quarantine the entire group if any timestamp is null (`missing_selection_timestamp`) or latest-timestamp ties have conflicting business attributes (`conflicting_latest_records`). For identical latest ties, including matching null attributes, select the smallest `source_row_id` and audit the others as duplicates; never use it to resolve missing timestamps or conflicting attributes.
- Compare account ID, plan, billing period, amount, service dates, and status as business attributes, excluding selection timestamps, batch metadata, and source-row IDs. Rebuild `canonical.quarantine_contracts` each run with every contributing record’s `source_table`, `source_row_id`, normalized `contract_id`, and `rejection_reasons`, plus safe attribution, period, amount, or count fields needed for reconciliation. Exclude restricted PII; ambiguous groups have no selected or duplicate/superseded audit outcome.
- Match the selected record's `account_id` to `canonical.dim_customer.customer_id`. If matched, populate `customer_id` and set the status to `resolved`. Otherwise, leave `customer_id` null and set the status to `unresolved_customer`.
- Keep all attributes from the selected contract. Contract start and end dates are inclusive. Retain cancelled, ended, and future contracts in the fact table.
- Rebuild `canonical.contract_record_audit` each run to track unselected records from nonquarantined groups. Include `source_row_id`, `contract_id`, and `selected_source_row_id`. Mark records as `duplicate` when their business attributes match the selected record; otherwise, mark them as `superseded`.
- Also record selected contracts with unresolved customer attribution in the audit table using `unresolved_customer`. These contracts remain in the fact table and are tracked separately from duplicate and superseded records.

**dbt tests and validations**

- Verify canonical quarantine reasons, source lineage, and PII exclusion against the rules above.
- `not_null`: `contract_id`, `resolution_status`, `billing_period`, `recurring_amount_usd`, `starts_on`, `status`, `source_row_id`; `unique`: `contract_id` and `source_row_id`.
- `accepted_values`: resolution = `resolved`/`unresolved_customer`; billing period = `annual`/`monthly`; status = `active`/`cancelled`. Validate nonnegative amounts, service-date order, and required end dates for cancelled contracts.
- Validate nonnull customer IDs against `dim_customer`, selected source-row lineage and attributes against `stg_contracts`, and selection or whole-group quarantine against the selection rules above. Resolved rows require a customer ID; unresolved rows require null.
- Every staged contract row must be selected, audited as duplicate/superseded, or retained in `canonical.quarantine_contracts` exactly once. Reconcile source counts and amounts across these outcomes; unresolved attribution entries do not count as additional source records.
- Unresolved customer attribution or expected canonical quarantine alone does not fail `dbt build`. Integrity, lineage, selection, or row-accounting violations fail the build and skip selected downstream dependencies.

#### `canonical.fct_workspace_usage`

dbt **table**, rebuilt each run from `staging.stg_usage` and `canonical.map_customer_workspaces`. One row per workspace and usage month; records without a workspace ID remain individually identifiable by `usage_id`.

```sql
CREATE TABLE canonical.fct_workspace_usage (
    usage_id VARCHAR NOT NULL,
    workspace_id VARCHAR,
    customer_id VARCHAR,
    resolution_status VARCHAR NOT NULL,
    usage_month DATE NOT NULL,
    active_users BIGINT NOT NULL,
    api_calls BIGINT NOT NULL,
    source_batch VARCHAR,
    extracted_at TIMESTAMP WITH TIME ZONE,
    source_row_id BIGINT NOT NULL
);
```

**Transformation rules**

- Deduplicate first by normalized `usage_id`, then by (`workspace_id`, `usage_month`) for nonnull workspace IDs, using `extracted_at` at both steps. Select a single record even with a null timestamp; otherwise select the latest when all timestamps are present. Quarantine the entire group if any timestamp is null (`missing_selection_timestamp`) or latest-timestamp ties have conflicting business attributes (`conflicting_latest_records`). For identical latest ties, including matching null attributes, select the smallest `source_row_id` and audit the others as duplicates; never use it to resolve missing timestamps or conflicting attributes. First-step quarantined groups do not enter the second step.
- Compare workspace, month, and counts as business attributes, excluding selection timestamps, batch metadata, and source-row IDs. Rebuild `canonical.quarantine_usage` each run with every contributing record’s `source_table`, `source_row_id`, normalized `usage_id`, and `rejection_reasons`, plus safe attribution, period, amount, or count fields needed for reconciliation. Exclude restricted PII; ambiguous groups have no selected or duplicate/superseded audit outcome.
- Treat repeated workspace-month records as replacements of monthly totals, not additional usage. Keep records with missing workspace IDs individually identifiable.
- Match each `workspace_id` to `canonical.map_customer_workspaces`. Use `resolved` or `unresolved_customer` when a mapping exists, `missing_workspace` when the ID is null, and `unknown_workspace` when no mapping exists. Populate `customer_id` only for resolved records.
- Keep historical usage for deleted workspaces, using the current workspace mapping for customer attribution.
- Rebuild `canonical.usage_record_audit` each run to track duplicate/superseded records from nonquarantined groups excluded during either deduplication step. Include `source_row_id`, `usage_id`, `disposition`, and `selected_source_row_id`. Mark records as `duplicate` when their business values match the selected record; otherwise, mark them as `superseded`. Preserve source-row traceability across both steps. Finalize outcomes after both steps: if a second-step group is ambiguous, quarantine its candidates and all contributing original staging rows, replacing provisional audit outcomes. Keep one final outcome per original row; for nonquarantined groups, retain audit links through both steps to the final selected record.

**dbt tests and validations**

- Verify canonical quarantine reasons, source lineage, and PII exclusion against the rules above.
- `not_null`: `usage_id`, `resolution_status`, `usage_month`, `active_users`, `api_calls`, `source_row_id`; `unique`: `usage_id`, `source_row_id`, and (`workspace_id`, `usage_month`) where workspace ID is nonnull.
- `accepted_values`: `resolved`, `unresolved_customer`, `missing_workspace`, `unknown_workspace`. Check nonnegative counts and first-of-month usage dates.
- Validate source-row lineage, selected values, customer relationships, mapping status, and selection or whole-group quarantine against the selection rules above at both deduplication steps.
- Every staging row must appear exactly once as selected, audited, or retained in `canonical.quarantine_usage`. Reconcile staging counts and usage totals against these source-record outcomes, without counting a row twice across steps or adding audited/quarantined records into canonical metrics.
- Fail `dbt build` on integrity, lineage, selection, or reconciliation violations. Unresolved workspace/customer attribution or expected canonical quarantine alone does not fail the build.

#### `canonical.fct_workspace_cloud_costs`

dbt **table**, rebuilt each run from `staging.stg_cloud_costs` and `canonical.map_customer_workspaces`. One row per normalized `cost_id` (logical primary key); multiple charges can belong to the same workspace and month.

```sql
CREATE TABLE canonical.fct_workspace_cloud_costs (
    cost_id VARCHAR NOT NULL,
    workspace_id VARCHAR,
    customer_id VARCHAR,
    resolution_status VARCHAR NOT NULL,
    usage_month DATE NOT NULL,
    compute_cost_usd DECIMAL(18,2) NOT NULL,
    storage_cost_usd DECIMAL(18,2) NOT NULL,
    source_batch VARCHAR,
    extracted_at TIMESTAMP WITH TIME ZONE,
    source_row_id BIGINT NOT NULL
);
```

**Transformation rules**

- For each normalized `cost_id`, use `extracted_at` to select records. Select a single record even with a null timestamp; otherwise select the latest when all timestamps are present. Quarantine the entire group if any timestamp is null (`missing_selection_timestamp`) or latest-timestamp ties have conflicting business attributes (`conflicting_latest_records`). For identical latest ties, including matching null attributes, select the smallest `source_row_id` and audit the others as duplicates; never use it to resolve missing timestamps or conflicting attributes.
- Compare workspace, month, and compute/storage amounts as business attributes, excluding selection timestamps, batch metadata, and source-row IDs. Rebuild `canonical.quarantine_cloud_costs` each run with every contributing record’s `source_table`, `source_row_id`, normalized `cost_id`, and `rejection_reasons`, plus safe attribution, period, amount, or count fields needed for reconciliation. Exclude restricted PII; ambiguous groups have no selected or duplicate/superseded audit outcome.
- Keep separate charges with different `cost_id` values, even when they belong to the same workspace and month. Do not aggregate costs at the workspace-month level in this fact table.
- Match each `workspace_id` to `canonical.map_customer_workspaces`. Use `resolved` or `unresolved_customer` when a mapping exists, `missing_workspace` when the ID is null, and `unknown_workspace` when no mapping exists. Populate `customer_id` only for resolved records.
- Keep historical costs for deleted workspaces, using the current workspace mapping for customer attribution.
- Rebuild `canonical.cloud_cost_record_audit` each run to track unselected records from nonquarantined groups. Include `source_row_id`, `cost_id`, `disposition`, and `selected_source_row_id`. Mark records as `duplicate` when their business values match the selected record; otherwise, mark them as `superseded`.

**dbt tests and validations**

- Verify canonical quarantine reasons, source lineage, and PII exclusion against the rules above.
- `not_null`: `cost_id`, `resolution_status`, `usage_month`, `compute_cost_usd`, `storage_cost_usd`, `source_row_id`; `unique`: `cost_id` and `source_row_id`.
- `accepted_values`: `resolved`, `unresolved_customer`, `missing_workspace`, `unknown_workspace`. Check nonnegative costs and first-of-month usage dates.
- Validate source-row lineage, selected amounts, customer relationships, mapping status, and selection or whole-group quarantine against the selection rules above.
- Every staging row must appear exactly once as selected, audited, or retained in `canonical.quarantine_cloud_costs`. Reconcile staging compute/storage totals against these source-record outcomes. Canonical financial totals include selected charges only, never audited or quarantined records.
- Fail `dbt build` on integrity, lineage, selection, or reconciliation violations. Unresolved attribution or expected canonical quarantine alone does not fail the build.

### 3.4 Intermediate Customer Metrics

#### `intermediate.int_customer_subscription_metrics`

dbt **table**, rebuilt each run from `canonical.dim_customer`, `canonical.fct_contracts`, `canonical.dim_workspaces`, and `canonical.map_customer_workspaces`. One row per customer and month; (`customer_id`, `reporting_month`) is the logical primary key. Full refresh recalculates totals from the current canonical records.

```sql
CREATE TABLE intermediate.int_customer_subscription_metrics (
    customer_id VARCHAR NOT NULL,
    reporting_month DATE NOT NULL,
    annualized_subscription_value_usd DECIMAL(18,2) NOT NULL,
    monthly_subscription_revenue_usd DECIMAL(18,2) NOT NULL
);
```

**Transformation rules**

- Generate completed reporting months from the earliest known contract start or mapped workspace creation through the latest completed calendar month. Include each customer beginning with their earliest contract start or mapped workspace creation.
- Calculate annualized subscription value (ASV) at month-end. Sum annual contract amounts unchanged and monthly contract amounts multiplied by 12. Include contracts effective on the final day of the month, using inclusive start/end dates.
- Calculate monthly subscription revenue independently. For each contract, divide its annualized amount by 12, multiply by active service days within the reporting month, and divide by calendar days in that month. Sum contract contributions by customer/month before rounding to two decimal places.
- Aggregate resolved contracts by customer/month before joining to the customer/month spine. Use zero when no eligible contracts exist.
- Include only contracts with `resolution_status = 'resolved'` in customer metrics. Unresolved contracts remain traceable in the canonical fact and its audit. Treat unresolved attribution as a data-quality exception rather than automatically failing this model. Exclude canonical-quarantined contracts from calculations. Do not consider affected totals complete when unresolved or quarantined contracts could change them.

**dbt tests and validations**

- `not_null`: all columns; `unique`: (`customer_id`, `reporting_month`); `relationships`: `customer_id` references `canonical.dim_customer`.
- Check nonnegative amounts and first-of-month reporting dates. Verify the customer/month spine includes every applicable customer and completed month.
- Validate ASV against month-end eligible contracts and revenue against service-day proration, including partial months and customers without eligible contracts. Verify joins do not multiply contract amounts.
- Reconcile calculated values against selected canonical contract records, accounting for unresolved attribution and canonical quarantine.
- Fail `dbt build` on integrity, calculation, uniqueness, or reconciliation violations. Unresolved attribution or expected canonical quarantine alone does not fail the build.

#### `intermediate.int_customer_monthly_usage`

dbt **table**, rebuilt each run from `intermediate.int_customer_subscription_metrics` and `canonical.fct_workspace_usage`. One resolved row per customer/month in the subscription metrics spine, plus unresolved totals grouped by reason/month. (`customer_id`, `reporting_month`) is the logical key for resolved rows; (`resolution_status`, `reporting_month`) identifies unresolved rows.

```sql
CREATE TABLE intermediate.int_customer_monthly_usage (
    customer_id VARCHAR,
    resolution_status VARCHAR NOT NULL,
    reporting_month DATE NOT NULL,
    product_usage_active_users BIGINT NOT NULL,
    product_usage_api_calls BIGINT NOT NULL
);
```

**Transformation rules**

- Reuse the completed customer/month spine from `intermediate.int_customer_subscription_metrics`. Produce one `resolved` row for each customer/month in that spine.
- Aggregate selected canonical usage by resolved `customer_id` and `usage_month` before joining to the spine. Sum `active_users` and `api_calls`; use zero when no usage records exist for a customer/month. Zero does not guarantee complete source reporting.
- Active users are summed workspace counts, not distinct people across workspaces.
- Group unattributed usage by (`resolution_status`, `usage_month`), with null `customer_id`. Preserve `missing_workspace`, `unknown_workspace`, and `unresolved_customer` totals, including months outside the customer/month spine.
- Do not include superseded or canonical-quarantined usage records in metric totals; their absence does not confirm complete coverage.

**dbt tests and validations**

- `not_null`: `resolution_status`, `reporting_month`, `product_usage_active_users`, `product_usage_api_calls`; `unique`: (`customer_id`, `reporting_month`) for resolved rows and (`resolution_status`, `reporting_month`) for unresolved rows.
- `relationships`: nonnull `customer_id` references `canonical.dim_customer`. Accepted statuses: `resolved`, `missing_workspace`, `unknown_workspace`, `unresolved_customer`. Only resolved rows have nonnull customer IDs.
- Check nonnegative counts and first-of-month reporting dates. Verify exactly one resolved row for every customer/month in the subscription metrics spine.
- Reconcile resolved and unresolved usage totals against selected canonical usage records by month, without multiplying counts through joins.
- Fail `dbt build` on integrity, uniqueness, coverage, or reconciliation violations. Unresolved attribution or expected canonical quarantine alone does not fail the build.

#### `intermediate.int_customer_monthly_cloud_costs`

dbt **table**, rebuilt each run from `intermediate.int_customer_subscription_metrics` and `canonical.fct_workspace_cloud_costs`. One resolved row per customer/month in the subscription metrics spine, plus unallocated totals grouped by reason/month. (`customer_id`, `reporting_month`) is the logical key for resolved rows; (`resolution_status`, `reporting_month`) identifies unresolved rows.

```sql
CREATE TABLE intermediate.int_customer_monthly_cloud_costs (
    customer_id VARCHAR,
    resolution_status VARCHAR NOT NULL,
    reporting_month DATE NOT NULL,
    cloud_cost_usd DECIMAL(18,2)
);
```

**Transformation rules**

- Reuse the completed customer/month spine from `intermediate.int_customer_subscription_metrics`. Produce one `resolved` row for each customer/month in that spine.
- Aggregate selected canonical charges by resolved `customer_id` and `usage_month` before joining to the spine. Sum `compute_cost_usd + storage_cost_usd`.
- Use `NULL` when a customer/month has no matching cost records, since cost coverage cannot be confirmed. Use zero only when complete coverage is independently established. Matching charges provide a cost total but do not independently prove completeness.
- Group unallocated charges by (`resolution_status`, `usage_month`), with null `customer_id`. Preserve `missing_workspace`, `unknown_workspace`, and `unresolved_customer` totals, including cost-only months outside the customer/month spine.
- Do not allocate unresolved charges to customers or include superseded or canonical-quarantined records in financial totals.

**dbt tests and validations**

- `not_null`: `resolution_status`, `reporting_month`; `unique`: (`customer_id`, `reporting_month`) for resolved rows and (`resolution_status`, `reporting_month`) for unresolved rows.
- `relationships`: nonnull `customer_id` references `canonical.dim_customer`. Accepted statuses: `resolved`, `missing_workspace`, `unknown_workspace`, `unresolved_customer`. Only resolved rows have nonnull customer IDs; unresolved rows require a nonnull cost amount.
- Check nonnegative nonnull costs and first-of-month reporting dates. Verify exactly one resolved row for every customer/month in the subscription metrics spine.
- Reconcile resolved and unresolved cost totals against selected canonical charges by month, without multiplying amounts through joins. Validate that missing costs remain `NULL` unless complete coverage is established.
- Fail `dbt build` on integrity, uniqueness, coverage, or reconciliation violations. Unresolved attribution or expected canonical quarantine alone does not fail the build.

### 3.5 Published Customer Reporting View

#### `published.customer_monthly_metrics`

dbt **table**, rebuilt each run; one row per resolved customer per eligible completed reporting month.

```sql
CREATE TABLE published.customer_monthly_metrics (
    customer_id VARCHAR NOT NULL,
    customer_name VARCHAR,
    reporting_month DATE NOT NULL,
    annualized_subscription_value_usd DECIMAL(18,2),
    monthly_subscription_revenue_usd DECIMAL(18,2),
    product_usage_active_users BIGINT,
    product_usage_api_calls BIGINT,
    cloud_cost_usd DECIMAL(18,2),
    gross_margin DECIMAL(18,4)
);
```

**Transformation rules**

- Start from the customer/month spine in `intermediate.int_customer_subscription_metrics`.
- Join `canonical.dim_customer` for customer names and the three intermediate metric tables by customer ID and reporting month. Use only resolved customer rows.
- Include all eligible completed historical months, not just the latest month.
- Validate that every known workspace mapped to the customer and active during the reporting month has valid usage and cloud-cost coverage. A workspace is active when created on/before month-end and not deleted before month-start.
- Check workspace-level canonical records for coverage. Do not assume intermediate zero usage or nonnull aggregated cloud costs prove completeness.
- Require reliable subscription metrics and resolved attribution. Exclude canonical-quarantined records from metrics; use their available customer/workspace and period references to identify affected customer-months and prevent incomplete totals from being published.
- Exclude only affected customer-months when coverage or attribution is incomplete. Unaffected customer-months remain publishable.
- Preserve confirmed zero values. Never replace missing or unknown metrics with zero.
- Calculate `gross_margin` as `(monthly_subscription_revenue_usd - cloud_cost_usd) / monthly_subscription_revenue_usd * 100`, rounded to four decimal places. Return null when revenue is zero or required inputs are unknown.
- Do not include unresolved customer or workspace buckets in this table.
- Exclude contact emails, account notes, workspace names, and other restricted PII.

**dbt tests and validations**

- `not_null`: `customer_id`, `reporting_month`.
- `unique`: (`customer_id`, `reporting_month`).
- `relationships`: `customer_id` references `canonical.dim_customer`.
- Validate completed reporting months, customer names, metric calculations, workspace-level coverage, and gross-margin calculations.
- Verify published customer-months agree with the resolved intermediate aggregates.
- Verify incomplete customer-months are excluded and have corresponding data-quality exceptions.
- Confirm joins do not duplicate customer-months or multiply amounts.
- Confirm restricted PII is absent.

#### `published.monthly_data_quality_exceptions`

dbt **table**, rebuilt each run; exceptions for both published and unpublished customer-months.

```sql
CREATE TABLE published.monthly_data_quality_exceptions (
    reporting_month DATE,
    source_table VARCHAR NOT NULL,
    issue_category VARCHAR NOT NULL,
    issue_reason VARCHAR NOT NULL,
    workspace_id VARCHAR,
    customer_id VARCHAR,
    source_row_id BIGINT,
    excluded_financial_amount_usd DECIMAL(18,2),
    excluded_active_users BIGINT,
    excluded_api_calls BIGINT
);
```

**Transformation rules**

- Record missing usage or cloud-cost coverage for active customer workspaces, including affected customer-months.
- Use `issue_category = 'completeness'` with `issue_reason = 'missing_usage'` or `'missing_cloud_cost'`.
- Record unresolved attribution using `issue_category = 'mapping'` with specific reasons: `unresolved_customer`, `unknown_workspace`, or `missing_workspace`.
- Include unattributed usage and unallocated cloud costs without assigning them to customers.
- Include quarantined staging and canonical records with `issue_category = 'quarantine'` and their actual rejection reasons, including `missing_selection_timestamp` and `conflicting_latest_records`. Preserve each source-row exclusion without treating conflicting candidates as additive business totals.
- Preserve available source identifiers, workspace IDs, customer IDs, and reporting months.
- Missing-record exceptions have null `source_row_id`.
- When an invalid source date prevents determining the reporting month, retain null.
- Preserve known excluded financial amounts and usage counts. Leave unknown or inapplicable values null; never invent zeros.
- Retain exceptions for both published and unpublished customer-months.
- Use the documented staging/canonical quarantine outputs and this single published exceptions table.

**dbt tests and validations**

- `not_null`: `source_table`, `issue_category`, `issue_reason`.
- Accepted issue categories: `completeness`, `mapping`, `quarantine`.
- Validate issue reasons against their corresponding categories.
- Verify source-row lineage when `source_row_id` is available, including complete coverage of canonical-quarantined source records and their specific reasons.
- Confirm missing-record exceptions do not invent source-row IDs or missing amounts.
- Verify excluded customer-months have corresponding specific exceptions.
- Reconcile unresolved usage and cloud costs against canonical and intermediate records.
- Confirm restricted PII is absent.

## 4. Future Considerations

- **Incremental loading:** Replace full rebuilds with incremental processing as data volume grows, using change detection, lookback windows, and targeted reprocessing.
- **SCD Type 2 dimensions:** Introduce dbt snapshots or equivalent history tracking to preserve customer and workspace attribute changes and support historical attribution.
- **Historical corrections:** Define whether late-arriving data and source corrections should restate previously published months or whether finalized reporting periods should be frozen, with a controlled adjustment process.
- **GAAP compliance:** Work with Finance to validate revenue recognition, cost allocation, and gross-margin definitions before treating contractual estimates as accounting-compliant financial metrics.
- **dbt Semantic Layer:** Define governed metrics centrally using dbt's semantic modeling capabilities, enabling BI tools and other consumers to query consistent business metrics without writing SQL.
