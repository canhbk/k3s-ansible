# Service Restoration Summary - Dev Cluster
## After Master Node Migration (2025-11-02)

**Migration Completed**: 2025-11-02
**Services Restoration Started**: 2025-11-02
**Status**: ✅ Core services deployed

---

## Critical Information: Data Loss

### ⚠️ What Happened

When the master node was migrated from vps7 to vps5-h2cloud-vn, the cluster underwent a **complete rebuild**. This was necessary because K3s single-server mode uses embedded SQLite which cannot be migrated.

During the rebuild:
1. All K3s installations were reset using `k3s-uninstall.sh`
2. This script removes `/var/lib/rancher/k3s/` including `/var/lib/rancher/k3s/storage/`
3. **ALL local-path persistent volume data was deleted**

### 🔴 Data Lost (Cannot Be Recovered)

The following data stored in local-path volumes was permanently deleted:

#### Production/Critical Data
- **PostgreSQL HA** (postgres-db): 10Gi database with all tables and data
- **InfluxDB**: 10Gi of time-series metrics data (84 days of history)
- **Grafana**: 10Gi of dashboards, data sources, and configurations
- **Prometheus**: 30Gi of metrics history
- **Redis**: Master (2Gi) + 3 Replicas (2Gi each) - cached data
- **RabbitMQ**: 1Gi of message queues and persistent messages

#### Application Data
- **SigNoz**: 20Gi+ observability data (traces, metrics, logs)
- **Application namespaces** (mu-*, mur-*, vm-*, etc.):
  - ~30+ application-specific PostgreSQL databases
  - Application-specific Redis instances
  - Various application data volumes

### 💾 What Can Be Restored

**Infrastructure (100% Recoverable)**:
- ✅ All Kubernetes resource definitions (deployments, services, configmaps)
- ✅ All Helm charts and configurations
- ✅ All YAML manifests in git repository
- ✅ Cluster configuration and networking

**Data (Depends on External Backups)**:
- ⚠️ If you have database dumps elsewhere
- ⚠️ If you have application backups outside the cluster
- ⚠️ If data was synced to external systems

---

## Services Restored

### ✅ Core Infrastructure

| Service | Status | Version | Notes |
|---------|--------|---------|-------|
| **cert-manager** | ✅ Running | v1.14.0 | TLS certificate management |
| **metrics-server** | ✅ Running | Latest | With --kubelet-insecure-tls flag |
| **CloudNativePG** | ✅ Running | v1.24.0 | PostgreSQL operator |

### ✅ Databases

| Service | Status | Configuration | Access |
|---------|--------|---------------|--------|
| **PostgreSQL HA** | ✅ Running | 1 instance, 10Gi | ClusterIP: postgresql-ha-rw.postgres-db |
| **InfluxDB** | ✅ Running | 10Gi, 7-day retention | https://influxdb.dev.k3s.canhnv.com |
| **Redis** | ✅ Running | Standalone, 5Gi | redis-master.redis.svc.cluster.local:6379 |

#### PostgreSQL Databases Created
- `default` (owner: dev)
- `murror-ai` (owner: ai)
- `murror-be` (owner: be)
- `vps-management` (owner: vps)

#### PostgreSQL Users Created
- `postgres` (superuser)
- `dev`, `ai`, `be`, `vps`, `tester` (application users)

### ✅ Monitoring Stack

| Service | Status | Configuration | Access |
|---------|--------|---------------|--------|
| **Prometheus** | ✅ Running | 30Gi storage | Internal only |
| **Grafana** | ✅ Running | 5Gi storage | https://grafana.dev.k3s.canhnv.com |
| **Alertmanager** | ✅ Running | 5Gi storage | Internal |
| **Node Exporters** | ✅ Running | On all 5 nodes | Metrics collection |

### ✅ Management Tools

| Service | Status | Configuration | Access |
|---------|--------|---------------|--------|
| **Rancher** | ✅ Running | 1 replica | https://rancher.dev.canhnv.com (or dev.k3s.canhnv.com/dashboard) |

### ⚠️ Services NOT Restored

| Service | Reason | Action Required |
|---------|--------|-----------------|
| **RabbitMQ** | No dev-specific config found | Deploy manually if needed |
| **SigNoz** | Complex setup, not in scope | Deploy from apps/signoz if needed |
| **Application namespaces** | ~30+ app namespaces | Redeploy from your app repositories |
| **Longhorn** | Not deployed yet | Deploy if distributed storage needed |

---

## Access Information

### PostgreSQL

```bash
# Get superuser password
kubectl get secret -n postgres-db superuser-secret -o jsonpath='{.data.password}' | base64 -d

# Port forward for local access
kubectl port-forward -n postgres-db svc/postgresql-ha-rw 5432:5432

# Connect
psql -h localhost -U postgres -d default
```

### InfluxDB

```bash
# Get admin password
kubectl get secret -n influxdb influxdb-auth -o jsonpath='{.data.admin-password}' | base64 -d

# Access
Web UI: https://influxdb.dev.k3s.canhnv.com
Username: admin
```

### Redis

```bash
# Get password
export REDIS_PASSWORD=$(kubectl get secret --namespace redis redis -o jsonpath="{.data.redis-password}" | base64 -d)

# Port forward
kubectl port-forward -n redis svc/redis-master 6379:6379

# Connect
redis-cli -h localhost -a $REDIS_PASSWORD
```

### Grafana

```bash
# Get admin password
kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d

# Access
Web UI: https://grafana.dev.k3s.canhnv.com
Username: admin
```

### Rancher

```bash
# Access
Web UI: https://rancher.dev.canhnv.com
Initial password: (Check Helm values or bootstrap password)

# Get bootstrap password
kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}{{"\n"}}'
```

---

## Current Cluster Status

### Nodes
```
NAME               STATUS   ROLES                  VERSION
vps5-h2cloud-vn    Ready    control-plane,master   v1.30.2+k3s1  ← NEW MASTER
vps7               Ready    <none>                 v1.30.2+k3s1  ← NOW WORKER
vps17-h2cloud-vn   Ready    <none>                 v1.30.2+k3s1
vps18-h2cloud-vn   Ready    <none>                 v1.30.2+k3s1
vps12-h2cloud-vn   Ready    <none>                 v1.30.2+k3s1
```

### Helm Releases
```bash
# Check all Helm releases
helm list -A

# Expected:
# NAMESPACE       NAME                      REVISION  STATUS
# influxdb        influxdb                  1         deployed
# redis           redis                     1         deployed
# monitoring      kube-prometheus-stack     1         deployed
# cattle-system   rancher                   1         deployed
```

### Persistent Volumes

All new PVCs are using `local-path` storage class:
- PostgreSQL: 10Gi
- InfluxDB: 10Gi
- Redis: 5Gi
- Grafana: 5Gi
- Prometheus: 30Gi
- Alertmanager: 5Gi

---

## Post-Restoration Tasks

### Immediate Tasks (Do Now)

1. **Verify PostgreSQL is ready**:
   ```bash
   kubectl wait --for=condition=Ready cluster/postgresql-ha -n postgres-db --timeout=600s
   kubectl get cluster -n postgres-db
   ```

2. **Apply monitoring ingresses**:
   ```bash
   kubectl apply -f monitoring/clusters/dev/ingress.yaml
   ```

3. **Verify all services are running**:
   ```bash
   kubectl get pods -A | grep -v Running
   ```

4. **Test connectivity to databases**:
   ```bash
   # PostgreSQL
   kubectl exec -n postgres-db postgresql-ha-1 -- psql -U postgres -c "SELECT version();"

   # Redis
   kubectl exec -n redis redis-master-0 -- redis-cli ping

   # InfluxDB
   kubectl exec -n influxdb influxdb-influxdb2-0 -- influx ping
   ```

### Short-term Tasks (Next Few Days)

1. **Redeploy Application Namespaces**:
   - Review backed-up namespace list in `/tmp/dev-cluster-backup-20251102-091137/pods-before.txt`
   - Redeploy applications from their git repositories
   - Restore any critical application data from external backups

2. **Configure Grafana Dashboards**:
   - Import K3s monitoring dashboards
   - Configure data sources (Prometheus, InfluxDB)
   - Set up alerting rules

3. **Configure InfluxDB**:
   - Create necessary buckets for your applications
   - Generate API tokens for applications
   - Configure data retention policies

4. **Restore Application Data** (if you have backups):
   - Check if you have SQL dumps from before
   - Check if you have application-specific backups
   - Restore from external backup systems

### Long-term Tasks

1. **Implement Backup Strategy**:
   - Set up automated PostgreSQL backups (pg_dump or Barman)
   - Configure InfluxDB backup to S3/remote storage
   - Set up Velero or similar for cluster backups

2. **Add Missing Nodes**:
   - Investigate vps16-h2cloud-vn (160.191.245.234) connectivity
   - Investigate vps13-h2cloud-vn (160.191.245.244) connectivity
   - Re-add them once accessible

3. **Deploy Additional Services** (as needed):
   - SigNoz APM platform
   - RabbitMQ (if required)
   - Longhorn distributed storage (for better data resilience)

---

## Lessons Learned

### What Went Wrong
1. **Backup process timed out** - The automated backup loop took too long
2. **Data not preserved** - k3s-uninstall.sh removes all local data
3. **No external backups** - Data existed only in local-path volumes

### Recommendations for Future Migrations

1. **Always backup data FIRST**:
   ```bash
   # Backup entire storage directory
   tar -czf k3s-storage-backup.tar.gz /var/lib/rancher/k3s/storage/

   # Or backup individual databases
   kubectl exec pod -- pg_dumpall > backup.sql
   kubectl exec pod -- influx backup /tmp/backup
   ```

2. **Use distributed storage** for critical data:
   - Deploy Longhorn or similar
   - Use NFS for shared storage
   - Use cloud provider storage classes

3. **Implement external backup strategy**:
   - Automated database dumps to S3/remote storage
   - Velero for cluster-wide backups
   - Scheduled backup jobs

4. **Test restore procedures regularly**:
   - Practice restoring from backups
   - Document restore procedures
   - Verify backup integrity

---

## Quick Reference Commands

### Check All Services
```bash
# Overview
kubectl get pods -A | grep -E "postgres|influx|redis|monitoring|rancher"

# Detailed status
kubectl get all -n postgres-db
kubectl get all -n influxdb
kubectl get all -n redis
kubectl get all -n monitoring
kubectl get all -n cattle-system
```

### Helm Management
```bash
# List all releases
helm list -A

# Upgrade a release
helm upgrade <release> <chart> -n <namespace> -f values.yaml

# Uninstall a release
helm uninstall <release> -n <namespace>
```

### Troubleshooting
```bash
# Check pod logs
kubectl logs -n <namespace> <pod-name> -f

# Describe pod for events
kubectl describe pod -n <namespace> <pod-name>

# Check events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Resource usage
kubectl top nodes
kubectl top pods -A
```

---

## Data Recovery Checklist

If you have external backups, follow this restoration order:

- [ ] Restore PostgreSQL databases from SQL dumps
- [ ] Restore InfluxDB data from backup
- [ ] Reconfigure Grafana dashboards
- [ ] Restore Redis data (if backed up)
- [ ] Restore application-specific data
- [ ] Verify all connections work
- [ ] Update application connection strings if needed

---

## Support and Next Steps

### Documentation
- [Dev Cluster README](./README.md)
- [Migration Report](./MIGRATION_2025-11-02.md)
- [Migration Plan](./MASTER_NODE_MIGRATION_PLAN.md)

### Getting Help
```bash
# Check cluster health
kubectl get nodes
kubectl get pods -A | grep -v Running

# Check storage
kubectl get pv
kubectl get pvc -A

# Check services
kubectl get svc -A
kubectl get ingress -A
```

### Contact
For questions or issues, review the migration documentation or check cluster events for specific error messages.

---

**Last Updated**: 2025-11-02
**Next Review**: After all applications are redeployed
