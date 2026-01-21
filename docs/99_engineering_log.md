# Engineering Log – Olist Batch Data Platform

This document records the implementation steps, architectural decisions, and lessons learned during the project's development.
It serves as a personal technical journal to support future reference, knowledge retention, and project replication.
This file is not intended as formal project documentation.

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

## Phase 5 – Data Warehouse Setup

### BigQuery Structure
- Datasets created:
  - `olist_raw` for structured raw ingestion
  - `olist_analytics` for dbt-managed staging and analytics-ready marts
- Both datasets are deployed in the EU multi-region to align with data residency and governance requirements.

### IAM and Access Control
- Dataset-level IAM permissions applied to grant the runtime Service Account write access.
- Project-level permissions were intentionally kept minimal to enforce least privilege.

### Notes
- Separating raw and analytics datasets supports clearer data lifecycle management.
- Dataset-level IAM reduces blast radius compared to project-wide permissions.

---

## Phase 6 – Compute and Orchestration

### Compute Environment
- Compute Engine VM created using `e2-medium` (2 vCPU, 4 GB RAM).
- Ubuntu 22.04 LTS selected as the base operating system.
- 50 GB standard persistent disk allocated for Docker images and logs.
- Service Account `sa-olist-data-platform` attached to the VM.
- Authentication handled via Application Default Credentials (ADC).
- VM configured with ephemeral external IP and accessed via IAP-based SSH.

### Environment Validation
Initial SSH access to the Compute Engine VM was validated via IAP.  
System identity, Ubuntu 22.04 LTS, allocated compute resources, disk configuration, and outbound network connectivity were verified before runtime installation.

### Secure Access Validation (IAP + OS Login)
Secure SSH access to the Compute Engine VM was established using **Identity-Aware Proxy (IAP)** combined with **OS Login**.
The following actions were performed:
- Cloud IAP API was enabled at the project level
- SSH access was tunneled through IAP, avoiding direct internet exposure
- OS Login was used to dynamically provision the Linux user `nagelarenata9`
- No manual SSH keys were created or managed

Access was validated using:

```bash
gcloud compute ssh nagelarenata9@olist-data-platform-vm \
  --zone europe-west1-d \
  --tunnel-through-iap
```

### Notes on SSH Access Decisions

During the initial setup, SSH access to the Compute Engine VM was configured using Identity-Aware Proxy (IAP) combined with OS Login.

The intention at that stage was to experiment with an access pattern commonly found in corporate environments, prioritizing controlled access over direct exposure.

As the project evolved and day-to-day development became more frequent, direct SSH access using standard SSH keys was also enabled to simplify local development workflows and editor integration (e.g., VS Code Remote SSH).

Both approaches were tested to better understand their trade-offs in terms of security, usability, and operational overhead within the context of a single-developer project.

### Runtime Setup
Docker Engine and Docker Compose plugin were installed using the official Docker repository.  
Docker was configured to run without sudo privileges.  
The container runtime was validated using a test container (`hello-world`).

### Orchestration and Transformation
- Apache Airflow will orchestrate batch ingestion and transformation workflows.
- dbt will be used for staging, marts, testing, and documentation.
- Incremental processing will be based on ingestion date rather than CDC.

### Notes
- Airflow is intentionally used as an orchestrator only.
- Heavy transformations are delegated to BigQuery via dbt.

---

## Phase 7 – Lessons Learned So Far

- A documentation-first approach significantly improves architectural clarity and reduces rework during implementation.
- Separating formal architecture documentation from an engineering log helps balance professionalism with long-term knowledge retention.
- Implementing the platform in clearly defined phases reduces cognitive load and enables more deliberate technical decisions.
- Applying production-oriented practices (cost controls, IAM scoping, validation steps) to a personal project increases its technical credibility and long-term value.

---

## Next Planned Steps

- Finalize Apache Airflow deployment using Docker Compose
- Bring up Airflow core services (webserver, scheduler)
- Validate Airflow UI access and basic DAG execution
- Set up dbt runtime environment and project structure
- Implement batch ingestion pipelines from GCS to BigQuery raw tables
- Develop incremental staging and mart models using dbt
