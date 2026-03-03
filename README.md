# Olist Batch Data Platform (GCP | Airflow | dbt | BigQuery)

A production-like batch data platform that simulates a real-world e-commerce analytics environment using Apache Airflow, BigQuery, and Google Cloud Platform.

The project demonstrates end-to-end data engineering practices, including:

- Orchestration and dependency management
- Idempotent batch ingestion
- Partition-aware incremental processing
- Deterministic surrogate key generation
- Dimensional modeling (Kimball-style star schema)
- Operational metadata tracking
- Cost control under cloud free-tier constraints
---

## Architecture Overview

The platform is built on Google Cloud Platform and follows a modern batch analytics architecture:

- **Cloud Provider:** GCP (EU region)
- **Storage:** Google Cloud Storage (raw landing zone)
- **Orchestration:** Apache Airflow (Docker on Compute Engine)
- **Data Warehouse:** BigQuery
- **Transformation:** dbt (staging, intermediate and analytical models implemented)
- **Visualization:** Looker Studio 

Data flows:

GCS → Airflow → BigQuery Raw → dbt (Staging/Silver → Intermediate → Marts/Gold) → Looker Studio

---

## Data Modeling (dbt)

The transformation layer follows a layered modeling approach:

- **Staging (Silver):** Source-aligned models with data type casting, standardization and ingestion lineage.
- **Intermediate:** Current-state models built using load_date and ingestion_ts to resolve latest records.
- **Marts (Gold):** Business-ready dimensional models designed for analytics and BI consumption.

### Model structure:

models/
  staging/
  intermediate/
  marts/
    dimensions/
    facts/

### All models include:
- Data quality tests (not_null, unique, relationships)
- Incremental-ready structure
- Source lineage and operational metadata

### Dimensional Modeling Strategy

The analytical layer follows Kimball-style dimensional modeling principles:

- Deterministic surrogate keys (INT64) generated via FARM_FINGERPRINT
- Natural keys preserved for reconciliation and traceability
- Degenerate dimensions (e.g., order_id) retained in fact tables
- Conformed dimensions shared across multiple facts
- Star schema structure designed for BI efficiency and analytical clarity

                dim_customers
                       |
dim_date ← fact_order_items → dim_products
                       |
                 dim_sellers

---

## Dimensional Model (Gold Layer)

The Gold layer implements a star schema designed for analytical consumption.

### Fact Tables

#### fact_order_items
Grain: one row per (order_id, order_item_id)

Contains:
- Degenerate dimensions: order_id, order_item_id
- Foreign keys: product_key, seller_key, customer_key
- Date keys:
  - order_purchase_date_key
  - shipping_limit_date_key
- Measures:
  - item_qty (always 1)
  - item_price
  - item_freight
  - item_gmv (price + freight)

#### fact_orders
Grain: one row per order_id

Contains:
- Degenerate dimension: order_id
- Foreign key: customer_key
- Date keys:
  - order_purchase_date_key
  - order_delivered_customer_date_key
  - order_estimated_delivery_date_key
  - order_approved_date_key
- Metrics:
  - order_status
  - delivery_days
  - delivery_delay_days
  - is_delivered
  - is_delivered_on_time

### Dimensions

- dim_date (date_key INT64 in YYYYMMDD format)
- dim_products (product_key INT64, product_id preserved)
- dim_sellers (seller_key INT64, seller_id preserved)
- dim_customers (customer_key INT64, customer_id preserved, customer_unique_id as attribute)

All surrogate keys are generated deterministically using FARM_FINGERPRINT with sign-bit masking for safe INT64 values.

### Surrogate Key Strategy

Surrogate keys are generated deterministically using:

farm_fingerprint(concat(...)) & 0x7fffffffffffffff

This ensures:
- Deterministic rebuild behavior
- INT64 non-negative values
- No dependency on sequences
- Idempotent dimensional modeling

---

## Key Features

- Batch ingestion from CSV files stored in GCS
- Historical raw layer versioned by `load_date`
- Idempotent partition loads (existing partitions are replaced during reprocessing)
- BigQuery tables partitioned by `load_date`
- Ingestion metadata added to all records:
  - `load_date`
  - `ingestion_ts`
  - `source_file`
  - `source_uri`
- Reprocessing safety: each execution replaces the target `load_date` partition, ensuring idempotent behavior and preventing duplicate records
- Sequential execution using Airflow pools to control resource usage
- Cost-aware architecture designed for GCP Free Trial
- Secure authentication using:
  - Service Account attached to VM
  - Application Default Credentials (ADC)
  - IAP + OS Login for SSH access

---

## Data Quality

Data quality is enforced using dbt tests:

- Primary key uniqueness
- Not-null constraints
- Referential integrity between facts and dimensions
- Accepted values and domain validation
- The current implementation includes 70+ automated data tests executed during each dbt build.

---

## End-to-End Execution

### Airflow DAG Execution

The ingestion pipeline runs sequentially to control memory usage and BigQuery costs.

![Airflow DAG Graph](docs/images/airflow/airflow_dag_graph_raw_ingestion.png)

![Airflow DAG Run Success](docs/images/airflow/airflow_dag_run_success_olist_raw_ingestion.png)

---

### BigQuery Layered Structure

Datasets created and managed by the pipeline:

- `olist_raw`
- `olist_raw_tmp`
- `olist_analytics`

![BigQuery Dataset Structure](docs/images/bigquery/bigquery_datasets_layered_structure.png)

---

### Raw Table Design

Raw tables are partitioned by ingestion date and include operational metadata.

![Raw Schema with Metadata](docs/images/bigquery/bigquery_raw_orders_schema_with_ingestion_metadata.png)

---

### Data Preview

Example data loaded into the raw layer.

![Orders Preview](docs/images/bigquery/bigquery_orders_preview_with_metadata.png)

---

### Partition Configuration

Tables are partitioned by `load_date` to support incremental processing.

![Partition Details](docs/images/bigquery/bigquery_raw_orders_partition_details_load_date.png)

---

### BigQuery Jobs Execution

All ingestion jobs are executed by Airflow using the platform Service Account.

![BigQuery Jobs](docs/images/bigquery/bigquery_jobs_airflow_execution_sa.png)

---

### dbt Execution – Staging and Intermediate Layers

Staging and intermediate models were successfully built and validated with data quality tests.

![dbt Build Success](docs/images/bigquery/dbt_staging_intermediate_build_success.png)

---

## Cost Management

This project was developed under the GCP Free Trial and applies basic FinOps principles:

- Project budget with alert thresholds
- Lightweight Compute Engine configuration
- VM stopped when not in use
- Sequential pipeline execution to avoid cost spikes

---

## Security

- No service account keys (JSON)
- Authentication via Application Default Credentials (ADC)
- Dedicated runtime Service Account
- Secure SSH via IAP + OS Login
- IAM scoped using least-privilege principles

---

## Reproducibility Baseline (v0)

This repository has a validated baseline for the ingestion layer.

Verified scope:
- Airflow running on Docker Compose (webserver + scheduler + postgres)
- One-shot ingestion DAG executed successfully
- GCS → BigQuery load into `olist_raw` with ingestion metadata
- Partition-based idempotency (`load_date` partition overwrite)

If issues occur after this point, they are expected to be related to subsequent work (dbt models, tests, marts, dashboards, etc.).

See docs/baseline-ingestion-v0.md for full reproducibility instructions.

---

## Project Status

Current implementation:

- Raw ingestion pipeline (Airflow)
- Staging and intermediate dbt models
- Latest-state resolution using ingestion metadata
- 70+ automated data quality tests
- Layered warehouse architecture (Raw → Silver → Gold)

Next steps:

- Build dimensional marts (facts and dimensions)
- Implement incremental materializations
- Publish Looker Studio dashboards

---

## Documentation

Detailed architecture and design decisions are available in:

- `docs/00_project_scope.md`
- `docs/01_cost_management.md`
- `docs/02_authentication_and_security.md`
- `docs/03_architecture.md`
- `docs/baseline-ingestion-v0.md`
- `docs/99_engineering_log.md`

---

## Current Phase

Raw ingestion layer completed and stabilized.

Future development will focus on:
- Analytical marts (Gold)
- Looker Studio dashboards