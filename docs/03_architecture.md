# Architecture Overview

## Purpose
This document describes the high-level architecture of the project and how data flows across its components.

The platform is designed to model a **batch-oriented analytics environment** for an e-commerce domain, with an emphasis on clarity, reproducibility, and separation of concerns.

The architectural choices documented here aim to:
- apply common data engineering design patterns
- support traceability across ingestion and transformation steps
- separate ingestion, transformation, and consumption responsibilities
- remain compatible with the constraints of a small, single-project setup

This document focuses on describing architectural intent and structure rather than evaluating architectural quality or performance.

## High-Level Components
- **Source (Batch files):** Olist e-commerce dataset, originally published on Kaggle and treated as periodic batch CSV deliveries.
- **Storage / Landing Zone:** Google Cloud Storage (GCS) acts as the landing zone and data lake.
  Raw batch files are stored in an append-only layout using uniform access control.
- **Orchestration:** Apache Airflow running on a Compute Engine VM via Docker Compose.
- **Warehouse:** BigQuery with separate datasets for raw ingestion (`olist_raw`) and analytics modeling (`olist_analytics`).
- **Transformations & Modeling:** dbt used for staging and analytical marts.
- **Consumption:** Looker Studio dashboards built on top of curated BigQuery tables.

## Region and Data Residency
All resources are deployed in **europe-west1 (Belgium)**.

BigQuery datasets are created using **EU-compatible locations**, ensuring consistent data locality across storage, processing, and analytics layers.

## Data Flow (End-to-End)

### 1. Batch Arrival (GCS Raw)
- Batch files are placed in Google Cloud Storage using a date-partitioned path:
  - `gs://<bucket>/olist/raw/dt=YYYY-MM-DD/<table>.csv`
- The raw storage layer is append-only, and existing files are not overwritten.

### 2. Ingestion and Raw Loading (Airflow)
- Apache Airflow orchestrates ingestion and loads each batch into BigQuery raw tables in the `olist_raw` dataset.
Each raw table is partitioned by `load_date` and includes ingestion metadata:
- load_date (DATE)
- ingestion_ts (TIMESTAMP)
- source_file (STRING)
- source_uri (STRING)
 
### 3. Transformations (dbt)
- dbt reads from BigQuery raw tables and builds downstream models:
  - **Staging (Silver):** standardized and typed models (`stg_*`)
  - **Marts (Gold):** analytics-oriented fact and dimension tables (`fact_*`, `dim_*`, `agg_*`)
- dbt runs incrementally using an ingestion-date-based strategy.
- dbt documentation is generated to describe models, columns, and relationships.

### 4. Data Quality
- dbt tests are used to validate basic constraints and relationships, such as:
  - uniqueness
  - not-null constraints
  - referential integrity
- Test failures are intended to block downstream steps in the orchestration flow.

### 5. Analytics Consumption
- Looker Studio connects to curated BigQuery mart tables for reporting and KPI exploration.


## Layering Strategy

### Raw
- Google Cloud Storage + BigQuery `olist_raw`
- Immutable historical record of ingested batches
- Partitioned by `load_date` for batch-level traceability

### Silver
- BigQuery `olist_analytics` (dbt staging models)
- Standardization and light cleaning
- Type casting, naming conventions, and limited deduplication within ingestion windows

### Gold
- BigQuery `olist_analytics` (dbt marts)
- Dimensional and aggregated models intended for analytical consumption


## Incremental Strategy
Incremental processing is based on ingestion date rather than source update timestamps.

- Raw ingestion is idempotent at the partition level
- Each batch replaces its corresponding `load_date` partition if reprocessed
- dbt models process only newly ingested partitions using logic equivalent to:
  - `load_date > max(load_date)` from the target model

This strategy is chosen for simplicity and traceability.

**Note:** Change Data Capture (CDC) and historical attribute tracking (e.g., SCD Type 2) are not implemented in this project.


## Orchestration Strategy (Airflow)
Airflow is responsible for:
- defining and controlling batch execution windows (manual trigger in the current phase)
- orchestrating dependencies (ingest → raw load → dbt run → dbt test)
- retry behavior and basic failure handling
- execution logging for traceability and debugging

Airflow is used strictly as an orchestrator; transformations are executed in BigQuery via dbt.

### Concurrency and Resource Management

Due to the limited memory available on the Compute Engine instance (e2-medium – 4 GB RAM), Airflow execution is configured to minimize resource contention.

The following controls are applied:

* DAG-level concurrency limits:

  * `max_active_runs = 1`
  * `max_active_tasks = 1`
* A dedicated Airflow pool (`bigquery_serial`) with a single slot
* BigQuery load and query operations assigned to this pool

This configuration enforces **sequential execution** of ingestion tasks, preventing memory pressure, container restarts, and out-of-memory (OOM) events.

This design choice prioritizes **pipeline stability and reproducibility** over execution speed, which is appropriate for a small, batch-oriented environment.

## Authentication Approach 
Authentication is handled via:
- a dedicated GCP Service Account attached to the Compute Engine VM
- Application Default Credentials (ADC) from the VM metadata server

Dataset-level IAM is used to grant the runtime Service Account write access to `olist_raw` and `olist_analytics`.

Further details are documented in the *Authentication and Security* section.

## Cost Controls (Free Trial Context)
The platform is designed to operate within Free Trial constraints:

- lightweight Compute Engine VM sizing
- project-level budget alerts
- VM stopped when not actively used

Cost controls are treated as a practical constraint rather than an architectural objective.


## Current Implementation Status

The following components are already implemented and validated:

### Infrastructure
- Compute Engine VM deployed in europe-west1
- Airflow running via Docker Compose (webserver, scheduler, metadata database)
- Authentication via Application Default Credentials (ADC)
- Dedicated runtime Service Account with least-privilege IAM

### Ingestion Layer
- Batch ingestion pipeline orchestrated by Airflow
- Source files stored in GCS using date-partitioned paths
- Data loaded into BigQuery `olist_raw`
- Tables partitioned by `load_date`
- Ingestion metadata added to all records:
  - load_date
  - ingestion_ts
  - source_file
  - source_uri
- Partition-level idempotency implemented

### Transformation Layer (dbt)
- Staging models (`stg_*`) for:
  - customers
  - orders
  - order_items
  - products
  - sellers
- Current-state views (`int_*__latest`) using:
  - load_date (primary ordering)
  - ingestion_ts (tie-breaker)
- Data quality tests implemented:
  - not_null
  - unique / unique combinations
  - accepted values
  - relationship integrity
- `dbt build` execution validated successfully

### Execution Flow
Current manual execution sequence:

Airflow ingestion → dbt build → dbt tests