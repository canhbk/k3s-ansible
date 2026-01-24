# Node Removal Procedures for K3s Clusters

## Overview
Comprehensive procedures for safely removing nodes from K3s clusters without data loss, based on analysis of node vps5 (209.126.10.183) removal from dev cluster.

## Key Findings from Analysis
- **Node vps5 Analysis**: 21 active pods, 6 persistent volumes (10Gi each for PostgreSQL, InfluxDB, Grafana)
- **Critical Stateful Workloads**: PostgreSQL HA, InfluxDB, Grafana with persistent storage
- **DaemonSet Pods**: Auto-reschedule (node-exporter, otel-agent, svclb pods)
- **Resource Usage**: 80% CPU requests, 55% memory - significant capacity on this node

## Critical Pre-Checks Required
1. **Verify cluster context** - Always confirm correct cluster before operations
2. **Check stateful workloads** - Identify PostgreSQL, databases, monitoring with PVs
3. **Confirm HA setup** - Ensure multi-instance for critical services before removal
4. **Backup verification** - Test backup procedures for all stateful data

## High-Risk Components Identified
- **PostgreSQL HA clusters** - Risk of service disruption if primary removed
- **InfluxDB time-series data** - Cannot recreate metrics data
- **Grafana dashboards** - Custom configurations and alerting rules
- **Application-specific databases** - Individual PostgreSQL instances per namespace

## Essential Command Patterns
```bash
# Safe drain sequence
kubectl cordon <node>
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --force --timeout=600s

# Stateful workload verification
kubectl get pods -n <namespace> -l <selector>
kubectl get pvc --all-namespaces | grep <pattern>

# Multi-cluster health checks
for context in dev eu jp sg sg2 us vn vn2; do kubectl config use-context $context && kubectl get nodes; done
```

## Documentation Requirements
- Update `/Users/canhnv/development/canhnv/k3s-ansible/docs/clusters/dev/README.md`
- Update `/Users/canhnv/development/canhnv/k3s-ansible/inventory.dev.local.yml`
- Remove node from LoadBalancer IPs section in cluster docs
- Update node count and capacity information

## Rollback Strategies
- Keep node accessible during procedure for quick re-add
- Maintain all backups until verification complete
- Document exact Ansible commands for node rejoin
- Test restore procedures for all backed-up services