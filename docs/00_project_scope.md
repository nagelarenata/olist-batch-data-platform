# Project Scope – Olist Batch Data Platform

## Objective
Design and implement a production-like batch data platform that simulates a real-world e-commerce analytics environment using the Olist dataset.

The primary goal of this project is to demonstrate data engineering best practices, including orchestration, incremental ingestion, analytics modeling, data quality, security, and cost awareness.

## Data Source
- Olist Brazilian e-commerce dataset (Kaggle)
- Source data provided as static CSV files
- Dataset is treated as periodic batch deliveries, simulating an e-commerce data extraction process

## Load Strategy
- Batch-oriented ingestion
- Append-only raw layer
- Raw data versioned by ingestion date (`dt=YYYY-MM-DD`)
- No in-place updates to raw data

## Incremental Strategy
This project adopts an ingestion-date–based incremental strategy:

- Each batch is ingested independently
- Raw tables retain all historical batches
- Downstream transformations process only newly ingested data
- Incremental logic is driven by `load_date`, not by source update timestamps

This approach prioritizes auditability, simplicity, and reproducibility over change data capture (CDC).

## Architecture Decisions
- Cloud Provider: Google Cloud Platform (GCP)
- Region: europe-west1 (Belgium)
- Storage Layer: Google Cloud Storage (GCS)
- Orchestration: Apache Airflow
- Transformation and Modeling: dbt
- Data Warehouse: BigQuery
- Runtime Environment: Compute Engine VM with Docker Compose

## Security and Authentication
- No service account key files are used
- Authentication is handled via Application Default Credentials (ADC)
- A dedicated Service Account is attached to the Compute Engine VM
- IAM permissions follow the principle of least privilege

## Cost Management
- Project runs under the GCP Free Trial
- Budget alerts are configured to monitor usage
- Infrastructure components are intentionally lightweight
- Compute resources are stopped when not in use

## Out of Scope
The following items are intentionally excluded to maintain a clear and focused scope:

- Real-time or streaming ingestion
- Change Data Capture (CDC) using update timestamps
- Slowly Changing Dimensions (SCD) Type 2
- Multi-cloud deployments
- Production-grade SLA enforcement

