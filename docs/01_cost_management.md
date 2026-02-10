# Cost Management and Controls

## Context
This project is developed under the Google Cloud Free Trial.  
Although credits are available, cost control is treated as a first-class architectural concern.

The objective is to prevent unnecessary resource consumption while simulating realistic batch data workloads.

## Budget Configuration
A project-level budget named **olist-batch-data-platform-budget** is configured with a total amount of USD 50.

Alert thresholds are defined at:
- 5% (early usage detection)
- 20% (cost anomaly detection)
- 50% (execution stop and review)

These alerts act as guardrails to prevent uncontrolled Free Trial credit consumption.

## Lightweight Infrastructure
Infrastructure choices are intentionally conservative:
- Small Compute Engine VM
- Minimal disk allocation
- Limited number of managed services
- No always-on components beyond what is strictly necessary
- BigQuery workload concurrency is intentionally limited through Airflow controls (sequential execution and a dedicated pool) to prevent uncontrolled query costs and resource spikes

This reflects a cost-aware approach suitable for batch-oriented workloads.

## Controlled VM Usage
To avoid idle compute costs, the Compute Engine VM is stopped when not in active use.

This operational practice:
- Prevents unnecessary charges during periods of inactivity
- Avoids accidental overnight or weekend resource usage
- Reduces reliance on always-on infrastructure

The VM is expected to be running only during:
- Pipeline execution windows
- Active development and debugging sessions

## Design Considerations
- Cost controls are implemented without impacting pipeline correctness
- Controlled compute usage is aligned with a batch-processing model
- This approach favors predictability and simplicity over high availability

## Limitations
- This setup does not aim to provide continuous availability
- Cost optimization takes precedence over production-grade uptime guarantees

## FinOps Principles Applied

This project applies basic FinOps practices appropriate for a small-scale environment:

- Budget monitoring with early alert thresholds
- Resource right-sizing based on actual workload needs
- On-demand compute usage instead of always-on infrastructure
- Controlled orchestration concurrency to prevent cost spikes

The goal is to demonstrate cost-awareness as part of architectural decision-making, even in a development and learning context.