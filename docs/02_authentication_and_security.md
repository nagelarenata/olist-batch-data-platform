# Authentication and Security

## Purpose
This document describes the authentication and security approach adopted by the project.
The goal is to follow production-oriented best practices while keeping the setup compatible with the GCP Free Trial.

Security decisions are documented before infrastructure provisioning to ensure consistency and avoid retrofitting access controls later.

## Authentication Strategy Overview
This project uses **Application Default Credentials (ADC)** for authentication.

No service account key files (JSON) are created, stored, or distributed at any point in the project.

Authentication is based on:
- A dedicated Google Cloud Service Account
- The Service Account being attached directly to the Compute Engine VM
- Workloads (Airflow, dbt, scripts) authenticating via the GCP metadata server

This approach avoids long-lived secrets and aligns with recommended GCP security practices.

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
- Run BigQuery jobs and access project datasets
- Authenticate workloads running inside Docker containers on the VM

Other projects or workloads do not reuse the Service Account.

## IAM and Least Privilege
IAM permissions follow the principle of least privilege.

Rather than assigning broad project-level roles, permissions are scoped as narrowly as possible.

### Planned IAM Roles
The Service Account is expected to receive:
- **BigQuery Job User**
  - Required to execute queries and load jobs triggered by Airflow and dbt
- **BigQuery Data Editor** (dataset-level)
  - Required to write and update tables in the raw and analytics datasets
- **Storage Object Admin** (bucket-level)
  - Required to read and write batch files and pipeline logs

Permissions are granted at the dataset or bucket level whenever possible and may be refined as the platform evolves.

## Runtime Authentication Flow
At runtime, authentication works as follows:
1. The Compute Engine VM starts with the Service Account attached
2. The GCP metadata server exposes short-lived credentials
3. Docker containers running Airflow and dbt request credentials via ADC
4. Google Cloud SDKs automatically resolve credentials without configuration files

No credentials are embedded in code, images, or environment variables.

## Validation and Verification
Authentication can be validated by:
- Executing a simple BigQuery query from a container
- Reading or writing a test object to the GCS bucket
- Verifying the active identity using GCP tooling

These checks confirm that ADC is functioning as expected.

## Security Scope and Limitations
This project does not aim to implement:
- Key rotation policies (keys are not used)
- Advanced secret management solutions
- Organization-wide IAM governance
- Network-level security controls (e.g., private service access)

The focus is on secure authentication practices appropriate for a single-project, batch-oriented platform.

## Security Summary
- No long-lived credentials stored or shared
- Authentication tied to runtime environment
- Least-privilege IAM roles
- Clear separation between code and credentials

This setup balances security, simplicity, and compatibility with the project scope.
