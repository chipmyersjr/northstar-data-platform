DBT := .venv/bin/dbt

.DEFAULT_GOAL := help

.PHONY: help install setup build test verify clean

help:
	@echo "install  Create a virtual environment and install pinned dependencies"
	@echo "setup    Restore a pristine local DuckDB warehouse"
	@echo "build    Build models and run tests"
	@echo "test     Run tests against the current warehouse"
	@echo "verify   Restore the warehouse, then build and test everything"
	@echo "clean    Remove local build artifacts"

install:
	python3 -m venv .venv
	.venv/bin/pip install -r requirements.txt

setup:
	cp data/northstar_raw.duckdb warehouse.duckdb

build:
	$(DBT) build --profiles-dir .

test:
	$(DBT) test --profiles-dir .

verify: setup build

clean:
	rm -rf .venv dbt_packages logs target warehouse.duckdb
