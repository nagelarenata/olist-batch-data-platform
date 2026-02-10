# Authentication and Security

## Purpose
This document describes the authentication and security approach adopted by the project.
The goal is to follow production-oriented best practices while keeping the setup compatible with the GCP Free Trial.

Security decisions are documented early to ensure consistency and avoid retrofitting access controls later in the implementation lifecycle.

## Authentication Strategy Overview
This project uses **Application Default Credentials (ADC)** for **all workload authentication** to Google Cloud services.

No service account key files (JSON) are created, stored, or distributed at any point in the project.

Authentication is split into two clearly defined domains:

- **Workload authentication (GCP services)** → handled via ADC  
- **Human access to compute (SSH)** → handled via IAP + OS Login

This separation follows patterns commonly observed in production environments, where machine identity and human access are handled independently.

## Workload Authentication (ADC)

Workload authentication is based on:

- A dedicated Google Cloud Service Account
- The Service Account being attached directly to the Compute Engine VM
- Workloads (Airflow, dbt, batch scripts) authenticating via the GCP metadata server

Google Cloud SDKs and client libraries automatically resolve credentials at runtime without explicit configuration.

This approach:
- Avoids long-lived secrets
- Eliminates credential distribution
- Aligns with recommended GCP security practices

## Why Not Service Account Keys (JSON)
Service account key files are intentionally avoided due to the following risks:
- Keys are long-lived credentials that can be accidentally leaked
- Keys may be committed to version control by mistake
- Key rotation adds operational overhead
- JSON keys do not reflect modern production authentication patterns on GCP

By relying on ADC, authentication is ephemeral and bound to the runtime environment.

## Service Account Design
A single dedicated Service Account is created for the data platform runtime.

The Service Account used by the platform is named `sa-olist-data-platform`.

**Responsibilities:**
- Access Google Cloud Storage buckets used by the platform
- Run BigQuery load jobs and queries
- Authenticate workloads running inside Docker containers on the VM

The Service Account is **not reused** by other projects or environments.

## IAM and Least Privilege
IAM permissions follow the principle of least privilege.

Rather than assigning broad project-level roles, permissions are scoped as narrowly as possible.

### IAM Roles

The Service Account currently has the following permissions:

- **BigQuery Job User**
  - Required to execute queries and load jobs triggered by Airflow and dbt
- **BigQuery Data Editor** (dataset-level)
  - Required to write and update tables in the raw and analytics datasets
- **Storage Object Admin** (bucket-level)
  - Required to read and write batch files and pipeline artifacts

Permissions are granted at the dataset or bucket level whenever possible and may be refined as the platform evolves.

## Runtime Authentication Flow
At runtime, authentication works as follows:
1. The Compute Engine VM starts with the Service Account attached
2. The GCP metadata server exposes short-lived credentials
3. Docker containers running Airflow and dbt request credentials via ADC
4. Google Cloud SDKs automatically resolve credentials without configuration files

No credentials are embedded in:
- source code
- Docker images
- environment variables
- configuration files

## Human Access to Compute (SSH)

Human access to the Compute Engine VM is handled separately from workload authentication.

Access is performed using **Identity-Aware Proxy (IAP)** combined with **OS Login**:

- SSH connections are tunneled through IAP (`--tunnel-through-iap`)
- No public SSH access is exposed to the internet
- The VM does not require a public IP for administrative access
- OS Login dynamically provisions the Linux user `nagelarenata9`
- No manual SSH key management is required

This approach:
- Avoids exposing SSH ports publicly
- Centralizes access control via IAM
- Improves security compared to direct external SSH access
- Reflects production-oriented access patterns

This setup prioritizes secure administrative access while remaining practical for a single-developer environment.

## Validation and Verification
Authentication can be validated by:
- Executing a simple BigQuery query from within a Docker container
- Reading or writing a test object to the GCS data lake bucket
- Verifying the active identity using GCP tooling

These checks confirm that ADC is functioning as expected.

## Security Scope and Limitations
This project intentionally limits its security scope.

The goal is not to implement a fully hardened or enterprise-grade security model, but rather to document and apply authentication practices commonly used in production environments, within the constraints of a single-project, batch-oriented setup.

The project does not aim to cover:

- Service account key rotation (service account keys are not used)
- Advanced secret management solutions
- Organization-wide IAM governance
- Network-level security controls such as Private Service Connect or VPC Service Controls

These topics are considered out of scope for the current stage and purpose of the project.

## Security Summary
The authentication and security design documented here reflects the following intentions:

- Avoid storing or distributing long-lived credentials
- Tie workload authentication to the runtime environment
- Apply IAM permissions using a least-privilege approach
- Keep a clear separation between workload identity and human access

The focus is on documenting the rationale behind these choices rather than asserting their effectiveness or completeness.