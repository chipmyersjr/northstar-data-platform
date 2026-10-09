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

The example model only proves that the supplied environment works. Replace or
remove it as you build the requested staging and canonical layers.

Every raw value is stored as text, and the tables include the batch metadata
needed to reason about lineage. You may export tables from DuckDB if files are
more convenient for inspection. Ingestion code is not part of the exercise.
