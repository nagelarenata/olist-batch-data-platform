# Baseline - Ingestion v0

This document defines the validated and reproducible baseline for the ingestion layer of the platform.

## What is considered "done" in this baseline
- Airflow running via Docker Compose (webserver, scheduler, postgres)
- Ingestion DAG executed successfully
- Raw tables created in BigQuery (`olist_raw`) partitioned by `load_date`
- Ingestion metadata columns present: `load_date`, `ingestion_ts`, `source_file`, `source_uri`
- Idempotent behavior by partition overwrite (delete + insert per `load_date`)

## How to start Airflow
```bash
cd ~/projects/olist-batch-data-platform
docker compose up -d
docker compose up airflow-init
```

## How to run the DAG
- Open Airflow UI
- Trigger: 01_olist_raw_ingestion_once

## How to validate in BigQuery
- Confirm datasets: olist_raw, olist_raw_tmp, olist_analytics (if already created)
- Pick one raw table (e.g. orders) and check:
  - Partitioning by load_date
  - Presence of ingestion metadata columns
  - Rows exist for load_date = 2018-10-01

## How to reset the environment (clean slate)
- Confirm datasets: olist_raw, olist_raw_tmp, olist_analytics (if already created)
```bash
cd ~/projects/olist-batch-data-platform
docker compose down
docker volume rm olist-batch-data-platform_postgres-db-volume 2>/dev/null || true
sudo rm -rf ./logs
docker compose up airflow-init
docker compose up -d
```