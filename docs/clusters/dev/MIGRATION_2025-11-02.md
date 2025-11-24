# Dev Cluster Master Node Migration - November 2, 2025

> **Note**: On 2025-11-24, VPS provider changed IPs for 4 nodes:
> - vps5-h2cloud-vn: 163.61.110.117 → 180.93.96.54
> - vps12-h2cloud-vn: 103.157.204.15 → 180.93.96.10
> - vps17-h2cloud-vn: 163.61.110.120 → 180.93.96.15
> - vps18-h2cloud-vn: 160.250.136.247 → 180.93.96.101
>
> This document reflects the old IPs from the November 2 migration.

## Migration Summary

**Date**: November 2, 2025
**Duration**: ~1 hour
**Status**: ✅ COMPLETED SUCCESSFULLY
**Downtime**: Complete cluster rebuild (dev environment)

## Objective

Transfer the master node role from **vps7** (154.26.131.23) to **vps5-h2cloud-vn** (163.61.110.117), while demoting vps7 to a worker node.

## Migration Results

### Before Migration
- **Master Node**: vps7 (154.26.131.23) - Ubuntu 20.04.5 LTS
- **Worker Nodes**: 6 nodes including vps5-h2cloud-vn
- **API Endpoint**: https://154.26.131.23:6443
- **Total Nodes**: 7

### After Migration
- **Master Node**: vps5-h2cloud-vn (163.61.110.117) - Ubuntu 22.04.2 LTS
- **Worker Nodes**: 4 nodes including vps7
- **API Endpoint**: https://163.61.110.117:6443
- **Total Nodes**: 5

### Nodes Removed
- vps16-h2cloud-vn (160.191.245.234) - Unreachable during migration
- vps13-h2cloud-vn (160.191.245.244) - Unreachable during migration

## Technical Details

### Migration Approach

Since K3s single-server mode uses embedded SQLite (not etcd), a live migration was not possible. The chosen approach was a **complete cluster rebuild**:

1. Documented current cluster state
2. Reset all K3s installations on all nodes
3. Updated inventory configuration
4. Deployed fresh cluster with new master
5. Updated kubeconfig and documentation

### Why Complete Rebuild?

- K3s single-server uses SQLite database that cannot be migrated
- Certificates are bound to specific node IPs
- Clean slate ensures no legacy configuration issues
- Development environment allows acceptable downtime

## Steps Performed

### Phase 1: Backup and Preparation
- ✅ Created backup directory at `/tmp/dev-cluster-backup-20251102-091137/`
- ✅ Documented current node states
- ✅ Saved cluster topology information

### Phase 2: Cluster Reset
- ✅ Uninstalled K3s from vps7 (old master)
- ✅ Uninstalled K3s from all agent nodes
- ✅ Cleaned up all K3s data and configuration files

### Phase 3: Cluster Redeployment
- ✅ Updated `inventory.dev.local.yml`:
  - Moved vps5-h2cloud-vn (163.61.110.117) to server group
  - Moved vps7 (154.26.131.23) to agent group
  - Removed unreachable nodes (vps16, vps13)
- ✅ Deployed new cluster using Ansible:
  ```bash
  ansible-playbook playbooks/site.yml -i inventory.dev.local.yml
  ```

### Phase 4: Verification
- ✅ All 5 nodes joined successfully
- ✅ New master node confirmed: vps5-h2cloud-vn
- ✅ vps7 confirmed as worker node
- ✅ Cluster API accessible at new endpoint

### Phase 5: Configuration Updates
- ✅ Updated kubectl context configuration
- ✅ Merged new kubeconfig into main config
- ✅ Updated cluster documentation

## Final Cluster State

```
NAME               STATUS   ROLES                  AGE     VERSION        INTERNAL-IP
vps5-h2cloud-vn    Ready    control-plane,master   2m53s   v1.30.2+k3s1   163.61.110.117
vps7               Ready    <none>                 2m30s   v1.30.2+k3s1   154.26.131.23
vps17-h2cloud-vn   Ready    <none>                 2m32s   v1.30.2+k3s1   163.61.110.120
vps18-h2cloud-vn   Ready    <none>                 2m33s   v1.30.2+k3s1   160.250.136.247
vps12-h2cloud-vn   Ready    <none>                 2m31s   v1.30.2+k3s1   103.157.204.15
```

## Post-Migration Actions Required

### Immediate Actions
1. ✅ Verify cluster connectivity
2. ✅ Update kubeconfig on all development machines
3. ✅ Update documentation

### Application Redeployment
Since this was a complete cluster rebuild, **all applications need to be redeployed**. Services can be rebuilt from the infrastructure-as-code definitions in this repository:

#### Core Infrastructure
- [ ] Deploy cert-manager
- [ ] Deploy Longhorn storage (if needed)
- [ ] Deploy metrics-server

#### Databases
- [ ] Deploy CloudNativePG operator
- [ ] Deploy PostgreSQL HA clusters (`database/postgresql/clusters/dev/`)
- [ ] Deploy InfluxDB (`monitoring/clusters/dev/influxdb/`)
- [ ] Deploy Redis clusters (`redis/clusters/dev/`)
- [ ] Deploy RabbitMQ (`rabbitmq/clusters/dev/`)

#### Monitoring & Management
- [ ] Deploy Rancher (`apps/rancher/clusters/dev/`)
- [ ] Deploy SigNoz APM
- [ ] Deploy Prometheus & Grafana (`monitoring/clusters/dev/`)

#### Applications
- [ ] Redeploy application namespaces from git repository
- [ ] Restore any data from backups if necessary

### DNS Updates (If Needed)
If external DNS was pointing to the old master IP:
- Update A records from 154.26.131.23 → 163.61.110.117
- Or update your `/etc/hosts` file for development access

## Configuration Changes

### Inventory File
**File**: `inventory.dev.local.yml`

```yaml
k3s_cluster:
  children:
    server:
      hosts:
        163.61.110.117:  # vps5-h2cloud-vn - NEW MASTER
          ansible_user: root
          ansible_ssh_pass: __REDACTED__
    agent:
      hosts:
        154.26.131.23:  # vps7 - NOW AGENT
          ansible_user: root
          ansible_ssh_pass: __REDACTED__
        163.61.110.120:  # vps17-h2cloud-vn
          ansible_user: root
          ansible_ssh_pass: __REDACTED__
        160.250.136.247:  # vps18-h2cloud-vn
          ansible_user: root
          ansible_ssh_pass: __REDACTED__
        103.157.204.15:  # vps12-h2cloud-vn
          ansible_user: root
          ansible_ssh_pass: __REDACTED__
```

### Kubeconfig Update
The dev context now points to:
- **Server**: https://163.61.110.117:6443
- **Context**: dev
- **Cluster**: dev
- **User**: default_dev

## Lessons Learned

1. **SQLite Limitation**: K3s single-server mode with embedded SQLite does not support live master node migration
2. **Clean Rebuild**: For dev environments, complete rebuild is faster and cleaner than attempting complex migration
3. **Node Availability**: Always verify all nodes are accessible before starting migration
4. **Documentation**: Infrastructure-as-code in git repository makes rebuild straightforward
5. **OS Upgrade**: New master now runs Ubuntu 22.04.2 LTS (vs old 20.04.5 LTS)

## Benefits Achieved

1. ✅ **Newer OS**: Master node now on Ubuntu 22.04.2 LTS
2. ✅ **Better Location**: Master in Vietnam region for better local latency
3. ✅ **Clean State**: No legacy configurations or potential issues
4. ✅ **Simpler Topology**: Reduced from 7 to 5 nodes (removed unreachable nodes)
5. ✅ **Role Flexibility**: vps7 can now be used for workloads as worker node

## Risks and Mitigations

### Risk: Data Loss
- **Mitigation**: This is a development cluster; production data resides elsewhere
- **Note**: Basic state backup saved in `/tmp/dev-cluster-backup-20251102-091137/`

### Risk: Extended Downtime
- **Mitigation**: Development environment; acceptable downtime
- **Actual**: ~1 hour total migration time

### Risk: Missing Applications
- **Mitigation**: All infrastructure definitions in git repository
- **Action**: Redeploy from IaC definitions

## Support and References

### Related Documentation
- [Dev Cluster README](./README.md)
- [Migration Plan](./MASTER_NODE_MIGRATION_PLAN.md)
- [Infrastructure Overview](../../INFRASTRUCTURE.md)
- [Ansible Inventory](../../../inventory.dev.local.yml)

### Useful Commands

```bash
# Verify cluster
kubectl config use-context dev
kubectl get nodes -o wide
kubectl cluster-info

# Check API endpoint
kubectl config view | grep server

# Deploy services
kubectl apply -f path/to/manifests/

# Monitor deployment
kubectl get pods -A --watch
```

## Migration Team
- Executed by: AI Assistant with user approval
- Date: November 2, 2025
- Method: Automated via Ansible

## Approval and Sign-off

Migration completed successfully with all objectives met.

**Cluster Status**: ✅ Operational
**Next Steps**: Application redeployment as needed
**Rollback Option**: Available (can redeploy vps7 as master if needed within 7 days)

---
*End of Migration Report*
