# Engineering Log – Olist Batch Data Platform

This document records the implementation steps, architectural decisions, and lessons learned during the project's development.
It serves as a personal technical journal to support future reference, knowledge retention, and project replication.
This file is not intended as formal project documentation or marketing material.

---

## Phase 1 – Project Initialization and Design

### Repository and Documentation
- Repository created to host a production-like batch data platform project.
- A documentation-first approach was adopted before infrastructure provisioning.
- Core documentation artifacts were created early to guide implementation:
  - Project scope and objectives
  - Cost management and Free Trial constraints
  - Authentication and security strategy
  - High-level system architecture

### Notes
- Writing documentation before implementation helped clarify trade-offs and reduce rework.
- Separating architectural documentation from operational notes improved clarity and focus.

---

## Phase 2 – Cost Management and Governance

### Budget and Monitoring
- GCP project linked to the Free Trial billing account.
- A project-level budget was created: `olist-batch-data-platform-budget`.
- Budget total defined as USD 50 to act as a conservative cost guardrail.
- Alert thresholds configured at:
  - 5% (early usage detection)
  - 20% (cost anomaly detection)
  - 50% (execution stop and review)

### Notes
- Treating cost control as a first-class concern increased confidence during experimentation.
- Early alerts provide safety without limiting architectural choices.

---

## Phase 3 – Authentication and Security Design

### Service Account Strategy
- A dedicated Service Account was created for the platform runtime: `sa-olist-data-platform`.
- No service account key files (JSON) were generated or stored.
- Authentication strategy based exclusively on Application Default Credentials (ADC).

### IAM Design
- Principle of least privilege adopted from the start.
- Planned roles include:
  - BigQuery Job User
  - BigQuery Data Editor (dataset-level)
  - Storage Object Admin (bucket-level)

### Notes
- Defining authentication and IAM before provisioning compute resources avoided retrofitting access controls later.
- Avoiding long-lived credentials aligns better with production-grade security practices.

---

## Phase 4 – Storage Layer (Data Lake)

### Cloud Storage Setup
- Google Cloud Storage bucket created: `olist-data-lake-nagela`.
- Region set to `europe-west1`.
- Storage class: Standard.
- Uniform access control enabled.
- Public access prevention enforced.
- Hierarchical namespace intentionally disabled.

### Permissions
- Service Account `sa-olist-data-platform` granted Storage Object Admin role at the bucket level.

### Design Decisions
- The bucket is designated as the platform’s data lake and landing zone.
- Raw data ingestion follows an append-only strategy.
- No data was uploaded at this stage to preserve a clean baseline.

### Notes
- Using GCS as a landing zone improves auditability and enables reprocessing.
- Uniform access simplifies IAM management and avoids legacy ACL complexity.

---

## Phase 5 – Data Warehouse Preparation (Planned)

### BigQuery Structure
- Datasets planned:
  - `olist_raw` for structured raw ingestion
  - `olist_analytics` for staging, marts, and analytics-ready models
- BigQuery datasets will use EU-compatible locations for consistency with storage and governance requirements.

### Notes
- Separating raw and analytics datasets supports clearer data lifecycle management.
- Dataset-level IAM will be preferred over project-level permissions.

---

## Phase 6 – Compute and Orchestration (Planned)

### Compute Environment
- A Compute Engine VM will be provisioned with the Service Account attached.
- The VM will serve as the runtime environment for Airflow and dbt using Docker Compose.

### Orchestration and Transformation
- Apache Airflow will orchestrate batch ingestion and transformation workflows.
- dbt will be used for staging, marts, testing, and documentation.
- Incremental processing will be based on ingestion date rather than CDC.

### Notes
- Airflow is intentionally used as an orchestrator only.
- Heavy transformations are delegated to BigQuery via dbt.

---

## Phase 7 – Lessons Learned So Far

- Documentation-first design significantly improves architectural clarity.
- Separating formal documentation from an engineering log helps balance professionalism and memory retention.
- Incremental, phase-based implementation reduces cognitive load and improves decision quality.
- Treating a personal project with production discipline increases its long-term value.

---

## Next Planned Steps

- Create and configure BigQuery datasets (`olist_raw`, `olist_analytics`)
- Apply dataset-level IAM permissions
- Provision Compute Engine VM with Service Account attached
- Install Docker and Docker Compose
- Deploy Airflow and dbt runtime environments
- Begin batch ingestion and incremental pipeline implementation
