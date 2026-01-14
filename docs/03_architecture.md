# Architecture Overview

## Purpose
This document describes the high-level architecture of the project and how data flows across components.
The platform is designed to simulate a production-like batch analytics environment for an e-commerce domain.

## High-Level Components
- **Source (Batch files):** Olist e-commerce dataset, originally published on Kaggle and treated as periodic batch CSV deliveries
- **Storage / Landing Zone:** Google Cloud Storage (GCS) acting as the platform’s data lake and landing zone.
  Raw batch files are stored in an append-only layout using uniform access control.
- **Orchestration:** Apache Airflow running on a Compute Engine VM (Docker Compose)
- **Warehouse:** BigQuery for raw storage and analytics-ready datasets
- **Transformations & Modeling:** dbt for staging and marts (silver/gold)
- **Consumption:** Looker Studio dashboards built on top of curated BigQuery tables

## Region and Data Residency
All resources are deployed in **europe-west1 (Belgium)**, with **BigQuery datasets using EU-compatible locations**.
This ensures consistent data locality across storage and analytics layers.

## Data Flow (End-to-End)
1. **Batch Arrival (GCS Raw)**
   - Batch files are placed in GCS under a date-partitioned path:
     - `gs://<bucket>/olist/raw/dt=YYYY-MM-DD/<table>.csv`
   - The raw layer is **append-only** (no overwrites).

2. **Ingestion and Raw Loading (Airflow)**
   - Airflow orchestrates ingestion and loads each batch into BigQuery raw tables (`olist_raw` dataset).
   - Each raw table is **partitioned by `load_date`** and includes ingestion metadata:
     - `load_date` (DATE)
     - `ingestion_ts` (TIMESTAMP)
     - `source_file` (STRING)

3. **Transformations (dbt)**
   - dbt reads from BigQuery raw tables and builds:
     - **Staging (Silver):** standardized, typed, cleaned models (`stg_*`)
     - **Marts (Gold):** dimensional models and analytics-ready facts/dimensions (`dim_*`, `fact_*`, `agg_*`)
   - dbt runs incrementally using the ingestion-date strategy (see Incremental Strategy section).
   - dbt documentation is automatically generated to provide model-level lineage, descriptions, and data contracts.

4. **Data Quality**
   - dbt tests validate key constraints and relationships (e.g., uniqueness, not null, referential integrity).
   - Test failures prevent downstream consumption steps from running.

5. **Analytics Consumption**
   - Looker Studio connects to curated BigQuery marts for dashboards and KPIs.

## Layering Strategy
This project follows a layered approach to ensure auditability and maintainability:

- **Raw (GCS + BigQuery `olist_raw`)**
  - Immutable historical record of ingested batches
  - Partitioned by `load_date` for batch-level traceability

- **Silver (BigQuery `olist_analytics`, dbt staging)**
  - Standardization and cleaning
  - Type casting, column naming conventions, and basic deduplication within the ingestion window

- **Gold (BigQuery `olist_analytics`, dbt marts)**
  - Dimensional modeling (facts/dimensions) and analytics aggregates
  - Optimized for BI consumption and query performance

## Incremental Strategy
Incremental processing is based on ingestion date, not source update timestamps.

- Raw ingestion is append-only
- Each batch is associated with a `load_date`
- dbt models process only newly ingested partitions:
  - `load_date > max(load_date)` from the target model (or equivalent logic)
- This strategy prioritizes:
  - reproducibility
  - simplicity
  - auditability

**Note:** This approach does not implement CDC or historical attribute tracking (SCD Type 2).

## Orchestration Strategy (Airflow)
Airflow is responsible for:
- defining batch execution windows
- orchestrating dependencies (ingest → load raw → dbt run → dbt test)
- retries and failure handling
- logging and execution traceability

Airflow is intentionally used as an orchestrator; heavy transformations are performed in dbt/BigQuery.

Execution logs and basic runtime metrics are used to ensure traceability and support debugging.

## Authentication Approach 
Authentication is done via:
- a dedicated GCP Service Account attached to the Compute Engine VM
- Application Default Credentials (ADC) from the VM metadata server

This aligns the project with production-oriented security practices.

## Cost Controls (Free Trial Context)
The platform is designed to minimize idle cost:
- lightweight VM sizing
- budget alerts configured at the project level
- VM stopped when not in use (scheduled shutdown)

## Future Improvements
Potential extensions:
- partitioning and clustering tuning in BigQuery marts
- automated publishing of dbt documentation artifacts
- more advanced idempotency guards (e.g., batch ledger tables)
- incremental merge strategies and CDC simulation

