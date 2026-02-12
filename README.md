# Olist Batch Data Platform

A production-like batch data platform that simulates a real-world e-commerce analytics environment using Apache Airflow, BigQuery, and Google Cloud.

The project demonstrates end-to-end data engineering practices, including orchestration, incremental ingestion, metadata management, cost control, and layered data architecture.

---

## Architecture Overview

The platform is built on Google Cloud Platform and follows a modern batch analytics architecture:

- **Cloud Provider:** GCP (EU region)
- **Storage:** Google Cloud Storage (raw landing zone)
- **Orchestration:** Apache Airflow (Docker on Compute Engine)
- **Data Warehouse:** BigQuery
- **Transformation:** dbt (planned)
- **Visualization:** Looker Studio (planned)

Data flows:

GCS → Airflow → BigQuery Raw → dbt (Staging/Marts)

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

## End-to-End Execution

### Airflow DAG Execution

The ingestion pipeline runs sequentially to control memory usage and BigQuery costs.

![Airflow DAG Graph](docs/images/airflow_dag_graph_raw_ingestion.png)

![Airflow DAG Run Success](docs/images/airflow_dag_run_success_olist_raw_ingestion.png)

---

### BigQuery Layered Structure

Datasets created and managed by the pipeline:

- `olist_raw`
- `olist_raw_tmp`
- `olist_analytics`

![BigQuery Dataset Structure](docs/images/bigquery_datasets_layered_structure.png)

---

### Raw Table Design

Raw tables are partitioned by ingestion date and include operational metadata.

![Raw Schema with Metadata](docs/images/bigquery_raw_orders_schema_with_ingestion_metadata.png)

---

### Data Preview

Example data loaded into the raw layer.

![Orders Preview](docs/images/bigquery_orders_preview_with_metadata.png)

---

### Partition Configuration

Tables are partitioned by `load_date` to support incremental processing.

![Partition Details](docs/images/bigquery_raw_orders_partition_details_load_date.png)

---

### BigQuery Jobs Execution

All ingestion jobs are executed by Airflow using the platform Service Account.

![BigQuery Jobs](docs/images/bigquery_jobs_airflow_execution_sa.png)

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

## Project Status

Current implementation:

- Airflow deployed via Docker Compose
- Raw ingestion pipeline implemented and executed successfully
- Data loaded from GCS to BigQuery
- Partitioned raw tables with ingestion metadata
- Cost and security controls in place

Next steps:

- Implement dbt staging models
- Build analytical marts
- Add data quality tests
- Create Looker Studio dashboards

---

## Documentation

Detailed architecture and design decisions are available in:

- `docs/Architecture Overview.md`
- `docs/Authentication and Security.md`
- `docs/Cost Management and Controls.md`
- `docs/Engineering Log.md`
