# Northstar analytics challenge starter

This repository is the starting point for the Northstar challenge in the public
careers repository. `data/northstar_raw.duckdb` contains the supplied source
data in its `raw` schema. Do not modify the raw tables.

## Prerequisites

- Python 3.10 or newer
- `make`

## Commands

```sh
make install  # create .venv and install pinned dbt dependencies
make setup    # restore warehouse.duckdb from the pristine fixture
make build    # build and test the dbt project
make test     # run tests without rebuilding models
make verify   # restore, build, and test from a clean warehouse
```

The example model only proves that the supplied environment works. Replace or
remove it as you build the requested staging and canonical layers.

Every raw value is stored as text, and the tables include the batch metadata
needed to reason about lineage. You may export tables from DuckDB if files are
more convenient for inspection. Ingestion code is not part of the exercise.
