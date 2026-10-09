# Source database prerequisite

The source DuckDB database is provided separately and is required to run this
project. Place it at `data/northstar_raw.duckdb` before running setup.

Keep the original source database unchanged. From the repository root,
`make setup` copies it to `warehouse.duckdb`, which is used by the dbt project.

The source database is intentionally excluded from version control. The generated
warehouse is also Git-ignored; neither database is included in a repository clone.
