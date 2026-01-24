# Dev Cluster IP Migration - November 24, 2025

## Migration Overview

**Date**: November 24, 2025
**Reason**: VPS provider changed IPs for 4 nodes
**Status**: ⏳ Configuration updated, pending cluster redeployment
**Impact**: Cluster currently offline until new IPs become accessible

## IP Changes

### Node IP Mapping

| Node | Old IP | New IP | Role |
|------|--------|--------|------|
| vps5-h2cloud-vn | 163.61.110.117 | **180.93.96.54** | Master (control-plane) |
| vps12-h2cloud-vn | 103.157.204.15 | **180.93.96.10** | Worker |
| vps17-h2cloud-vn | 163.61.110.120 | **180.93.96.15** | Worker |
| vps18-h2cloud-vn | 160.250.136.247 | **180.93.96.101** | Worker |

### Unchanged Nodes

| Node | IP | Role |
|------|-----|------|
| vps13-h2cloud-vn | 160.191.245.244 | Worker |
| vps16-h2cloud-vn | 160.191.245.234 | Worker |

## Infrastructure Changes

### Cluster API Endpoint

- **Old**: `https://163.61.110.117:6443`
- **New**: `https://180.93.96.54:6443`

### LoadBalancer IP Pool

**Old IPs**:
- 163.61.110.117 (Master)
- 103.157.204.15 (vps12)
- 163.61.110.120 (vps17)
- 160.250.136.247 (vps18)
- 160.191.245.234 (vps16)
- 160.191.245.244 (vps13)

**New IPs**:
- 180.93.96.54 (Master)
- 180.93.96.10 (vps12)
- 180.93.96.15 (vps17)
- 180.93.96.101 (vps18)
- 160.191.245.234 (vps16) - unchanged
- 160.191.245.244 (vps13) - unchanged

## Service Impact

### PostgreSQL Services

#### LoadBalancer Service (postgres-murror-ai)

- **Service Type**: LoadBalancer
- **Old External IPs**: 154.26.131.23, 154.38.172.89, 209.126.10.183, 46.250.232.10, 5.104.86.195
- **New External IPs**: Will be reassigned from new node IP pool after redeployment
- **Database**: murror-ai
- **Port**: 5432
- **Users Affected**: AI team members

#### NodePort Service (postgres-murror-be-nodeport)

- **Service Type**: NodePort
- **Port**: 30543
- **Old Access Points**:
  - 154.26.131.23:30543
  - 163.61.110.120:30543
  - 160.250.136.247:30543
  - 163.61.110.117:30543
  - (and others)

- **New Access Points**:
  - 180.93.96.54:30543 (vps5 - master)
  - 180.93.96.10:30543 (vps12)
  - 180.93.96.15:30543 (vps17)
  - 180.93.96.101:30543 (vps18)
  - 160.191.245.234:30543 (vps16)
  - 160.191.245.244:30543 (vps13)

- **Old Connection String**:
  ```
  postgresql://be:__REDACTED__@154.26.131.23:30543/murror-be?schema=public
  ```

- **New Connection String** (use any new node IP):
  ```
  postgresql://be:__REDACTED__@180.93.96.54:30543/murror-be?schema=public
  ```

- **Database**: murror-be
- **Users Affected**: Backend team members

### Redis Services

#### RedisInsight LoadBalancer

- **Service Type**: LoadBalancer
- **Old External IPs**: 160.191.245.234, 160.250.136.247, 163.61.110.117, 163.61.110.120
- **New External IPs**: Will be reassigned from new node IP pool
- **Port**: 80 (NodePort: 32090)
- **Users Affected**: Developers using RedisInsight UI

### Other Services

All other LoadBalancer services will automatically receive new external IPs from the updated node pool after cluster redeployment.

## Files Updated

### Infrastructure Configuration

- ✅ `inventory.dev.local.yml` - Updated all 4 node IPs with timestamp comments

### Documentation

- ✅ `docs/clusters/dev/README.md`
  - Updated API endpoint
  - Updated node configuration table
  - Updated LoadBalancer IPs section
  - Added recent changes entry

- ✅ `docs/clusters/dev/POSTGRESQL.md`
  - Updated LoadBalancer service external IPs
  - Updated NodePort access points
  - Updated connection string examples

- ✅ `redis/clusters/dev/README.md`
  - Updated RedisInsight external IPs

- ✅ `cluster-rbac/clusters/dev/README.md`
  - Updated master node IP
  - Updated API endpoint

- ✅ `docs/clusters/dev/MIGRATION_2025-11-02.md`
  - Added IP change notice at the top

## Migration Checklist

### Pre-Migration (Completed)

- [x] Test SSH connectivity to new IPs - **Result**: Currently unreachable
- [x] Update Ansible inventory file
- [x] Backup current kubeconfig
- [x] Update all documentation

### Pending Tasks (Once IPs are Accessible)

- [ ] Verify SSH connectivity to all new IPs
- [ ] Redeploy K3s cluster using updated inventory:
  ```bash
  ansible-playbook playbooks/site.yml -i inventory.dev.local.yml
  ```
- [ ] Verify all nodes join successfully
- [ ] Check cluster health:
  ```bash
  kubectl config use-context dev
  kubectl get nodes -o wide
  kubectl get pods -A
  ```
- [ ] Verify LoadBalancer services get new IPs:
  ```bash
  kubectl get svc -A | grep LoadBalancer
  ```
- [ ] Test PostgreSQL NodePort access on new IPs
- [ ] Test RedisInsight access
- [ ] Update local kubeconfig with new API endpoint
- [ ] Notify external users of new connection endpoints

### Post-Migration Verification

- [ ] All nodes show as Ready
- [ ] Core services running (PostgreSQL, Redis, RabbitMQ, etc.)
- [ ] LoadBalancer services accessible
- [ ] NodePort services accessible
- [ ] Ingress domains resolving correctly
- [ ] Prometheus/Grafana collecting metrics
- [ ] All PVCs bound and data intact

## Network Troubleshooting

### Current Status (2025-11-24)

**New IPs Status**: Unreachable from external locations
- Ping test: 100% packet loss
- SSH test: Connection timeout
- Old IPs: No longer accessible

**Possible Causes**:
1. VPS provider still provisioning new IPs
2. Firewall rules not configured on provider side
3. Servers need internal network reconfiguration
4. DNS propagation for new IPs in progress

### When IPs Become Accessible

Once the new IPs are reachable:

1. **Test basic connectivity**:
   ```bash
   ping -c 5 180.93.96.54
   ssh root@180.93.96.54
   ```

2. **Verify all nodes can communicate**:
   ```bash
   # From each node, test connectivity to other nodes
   for ip in 180.93.96.54 180.93.96.10 180.93.96.15 180.93.96.101; do
     ping -c 2 $ip
   done
   ```

3. **Check K3s service status on old nodes** (if still configured):
   ```bash
   ssh root@180.93.96.54 "systemctl status k3s"
   ```

## External User Communication

### Users to Notify

1. **AI Team** - postgres-murror-ai LoadBalancer users
2. **Backend Team** - postgres-murror-be-nodeport users
3. **Developers** - RedisInsight UI users
4. **DevOps Team** - kubectl cluster access

### Communication Template

```
Subject: Dev Cluster IP Changes - Action Required

The VPS provider has changed IPs for our dev cluster nodes.

IMPACT:
- Cluster temporarily offline
- Database connection strings need updating
- Kubeconfig needs updating

NEW API ENDPOINT:
https://180.93.96.54:6443

NEW POSTGRESQL NODEPORT ENDPOINTS (port 30543):
- 180.93.96.54:30543
- 180.93.96.10:30543
- 180.93.96.15:30543
- 180.93.96.101:30543
- 160.191.245.234:30543
- 160.191.245.244:30543

LoadBalancer services (PostgreSQL AI access, RedisInsight) will get new IPs after redeployment.

Timeline: Cluster will be restored once new IPs become accessible.
```

## Rollback Plan

If issues occur after redeployment:

1. **Restore from backup**:
   ```bash
   cp ~/cluster-backups/config-dev-backup-20251124.yaml ~/.kube/config
   ```

2. **If old IPs were still working**, revert inventory:
   ```bash
   git checkout HEAD~1 inventory.dev.local.yml
   ```

3. **Redeploy with old configuration**:
   ```bash
   ansible-playbook playbooks/site.yml -i inventory.dev.local.yml
   ```

Note: This is unlikely to work as old IPs are already inaccessible.

## Lessons Learned

1. **IP Change Coordination**: VPS provider should provide advance notice for IP changes
2. **Backup Strategy**: Maintain recent cluster state backups before IP migrations
3. **Documentation**: Keep comprehensive IP mapping in docs for quick reference
4. **External Dependencies**: Document all external services depending on cluster IPs
5. **Testing**: Always test new IP connectivity before attempting redeployment

## Related Documentation

- [Dev Cluster Overview](./README.md)
- [PostgreSQL Documentation](./POSTGRESQL.md)
- [Previous Migration (2025-11-02)](./MIGRATION_2025-11-02.md)
- [Infrastructure Overview](../../INFRASTRUCTURE.md)

## Contact

For questions or issues related to this migration, contact the DevOps team.

---

*Last Updated: 2025-11-24*
*Status: Configuration complete, awaiting IP accessibility*
