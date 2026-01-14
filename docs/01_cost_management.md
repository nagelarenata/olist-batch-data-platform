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

This reflects a cost-aware approach suitable for batch-oriented workloads.

## Automated VM Shutdown
To avoid idle compute costs, the Compute Engine VM is automatically stopped when not in use.

This is achieved through scheduled jobs that:
- Shut down the VM outside defined execution or development windows
- Reduce reliance on manual intervention
- Prevent accidental overnight or weekend resource usage

The VM is only expected to be running during:
- Pipeline execution windows
- Active development and debugging sessions

## Design Considerations
- Cost controls are implemented without impacting pipeline correctness
- Automated shutdowns are aligned with a batch-processing model
- This approach favors predictability and simplicity over high availability

## Limitations
- This setup does not aim to provide continuous availability
- Cost optimization takes precedence over production-grade uptime guarantees
