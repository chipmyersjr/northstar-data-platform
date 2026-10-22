# Northstar analytics challenge starter

This repository is the starting point for the Northstar challenge in the public
careers repository. The separately supplied source DuckDB database contains
data in its `raw` schema. Keep the original source database unchanged.

## Prerequisites

- Python 3.10 or newer
- `make`
- The separately provided source database, placed at `data/northstar_raw.duckdb`.
  This file is required to run the project and is intentionally Git-ignored.
  See [data/README.md](data/README.md).

## Setup and run

The credential-free DuckDB `profiles.yml` is intentionally committed so a fresh
checkout uses the same local database configuration without manual profile setup.
In a typical production project, `profiles.yml` would remain untracked because it
can contain secrets and machine-specific settings.

From the repository root, after placing the source database at the path above:

```sh
make install  # create .venv and install pinned dbt dependencies
make setup    # copy the source database to warehouse.duckdb
make build    # build and test the dbt project
```

The generated `warehouse.duckdb` is also Git-ignored. `make setup` replaces it
with a fresh copy of the source database; keep the original source unchanged.

For subsequent validation:

```sh
make test     # run tests without rebuilding models
make verify   # restore, build, and test from a clean warehouse
```

## Example analyst queries

After completing `make install`, `make setup`, and a successful `make build`, run
from the repository root:

```sh
make queries
```

This opens `warehouse.duckdb` read-only and displays five labeled SQL examples
from `queries/`: annualized subscription value, product usage, cloud cost, and
gross-margin percentage by customer and reporting month, plus data-quality issues
filtered to April 2026. It does not rebuild data.

`published.customer_monthly_metrics` provides eligible customer-month metrics
without additional joins or cleaning. Omitted customer-months are unreportable,
not zero. `published.monthly_data_quality_exceptions` explains missing workspace
observations and unresolved usage/cost attribution; it does not include unresolved
contracts or customer-months with no active workspaces.

## Troubleshooting

DuckDB database locks can occur when another application or process has an active
connection to `warehouse.duckdb`. Close those connections and retry the command.

Every raw value is stored as text, and the tables include the batch metadata
needed to reason about lineage. You may export tables from DuckDB if files are
more convenient for inspection. Ingestion code is not part of the exercise.
