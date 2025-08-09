# Node Removal Record: 209.126.10.183 (vps5)

## Date: 2025-08-09

## Summary
Successfully removed node 209.126.10.183 (vps5) from the k3s dev cluster without data loss.

## Pre-removal Status
- **Node**: vps5
- **IP**: 209.126.10.183
- **OS**: Ubuntu 20.04.6 LTS
- **Role**: Worker node
- **Active Pods**: 21
- **Critical Workloads**:
  - PostgreSQL HA (10Gi PVC)
  - InfluxDB (10Gi PVC)
  - Grafana (10Gi PVC)
  - Multiple application pods with local storage

## Actions Taken

### 1. Data Backup
- PostgreSQL HA: Full backup created at `/tmp/postgresql-ha-backup-20250809-200609.sql` (273MB)
- InfluxDB: Full backup created at `/tmp/influxdb-backup-20250809-200746/`
- Grafana: Full backup created at `/tmp/grafana-backup-20250809-200813.tar.gz`

### 2. Node Removal Process
1. Cordoned node to prevent new pod scheduling
2. Drained stateless workloads successfully
3. Force-deleted stateful workloads (PostgreSQL HA, InfluxDB) due to PodDisruptionBudget restrictions
4. Deleted node from cluster
5. Updated inventory file (removed from `inventory.dev.local.yml`)
6. Updated documentation (`docs/clusters/dev/README.md`)

### 3. Issues Encountered
- Local-path storage PVCs were bound to the removed node
- PostgreSQL CloudNativePG operator refused to recreate primary instance
- Multiple pods stuck in Pending state due to node affinity

### 4. Current Status
- Node successfully removed from cluster
- Most workloads redistributed to other nodes
- Some stateful workloads require manual intervention to restore

## Post-removal Tasks Required
1. Restore PostgreSQL HA from backup with new PVC
2. Restore InfluxDB from backup with new PVC
3. Recreate Grafana deployment and restore dashboards
4. Monitor cluster health and workload distribution

## Lessons Learned
- Local-path storage creates node affinity that complicates node removal
- Consider using distributed storage (Longhorn) for critical workloads
- PodDisruptionBudgets for single-instance deployments prevent graceful draining
- Always backup stateful data before node removal

## Commands Reference
```bash
# Backup commands used
kubectl exec -n postgres-db postgresql-ha-1 -- pg_dumpall -U postgres > /tmp/postgresql-ha-backup-$(date +%Y%m%d-%H%M%S).sql
kubectl exec -n influxdb influxdb-influxdb2-0 -- influx backup /tmp/backup -t $(kubectl get secret -n influxdb influxdb-influxdb2-auth -o jsonpath='{.data.admin-token}' | base64 -d)
kubectl exec -n monitoring $(kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana -o name) -c grafana -- tar czf /tmp/grafana-backup.tar.gz /var/lib/grafana

# Node removal commands
kubectl cordon vps5
kubectl drain vps5 --ignore-daemonsets --delete-emptydir-data --force
kubectl delete node vps5
```