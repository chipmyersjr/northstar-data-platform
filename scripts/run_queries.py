from pathlib import Path

import duckdb


root = Path(__file__).resolve().parent.parent
try:
    connection = duckdb.connect(str(root / "warehouse.duckdb"), read_only=True)
except duckdb.Error as error:
    raise SystemExit(f"Cannot open warehouse.duckdb for reading: {error}") from error

try:
    for filename, label in (
        ("annualized_subscription_value.sql", "1. Annualized subscription value"),
        ("product_usage.sql", "2. Product usage (active users and API calls)"),
        ("cloud_cost.sql", "3. Cloud cost"),
        ("gross_margin.sql", "4. Gross-margin percentage"),
        ("data_quality_issues.sql", "5. Data-quality issues — April 2026"),
    ):
        print(label, flush=True)
        connection.sql((root / "queries" / filename).read_text()).show()
finally:
    connection.close()
