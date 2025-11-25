# Longhorn Deployment - SG3 Cluster

## Overview

- **Version**: 1.9.1
- **Deployment Date**: 2025-11-25
- **Cluster**: SG3 (8 nodes: 3 control-plane, 5 workers)
- **Configuration**: 3 replicas (production HA)

## Access

- **UI**: https://sg3.longhorn.canhnv.com
- **Default Credentials**: admin/admin (CHANGE IMMEDIATELY!)

To change password:
```bash
cd /Users/canhnv/development/canhnv/k3s-ansible/longhorn
./scripts/update-password-simple.sh
```

## Storage Classes

| Name | Replicas | Reclaim | Use Case |
|------|----------|---------|----------|
| longhorn (default) | 3 | Retain | General purpose |
| longhorn-retain | 3 | Retain | Important data |
| longhorn-fast | 2 | Delete | Performance-sensitive |
| longhorn-single | 1 | Delete | Non-critical/temporary |
| longhorn-static | 3 | Delete | Static provisioning |

## Configuration

### Replica Strategy
- **Default replicas**: 3 (survives 2 node failures)
- **CSI components**: 3 replicas each (attacher, provisioner, resizer, snapshotter)
- **UI replicas**: 2 (high availability)

### Storage Distribution
- **Total nodes**: 8 (all nodes participate in storage)
- **Replica anti-affinity**: Enabled (spreads replicas across nodes)
- **Auto-rebalancing**: Enabled (best-effort)

## Operations

```bash
# Deploy
make deploy-sg3

# Check status
make status-sg3

# Uninstall
make uninstall-sg3
```

## Deployment Status

**Last Deployment**: 2025-11-25

Components deployed:
- longhorn-manager: 8 pods (DaemonSet on all nodes)
- longhorn-ui: 2 pods (HA)
- csi-attacher: 3 pods
- csi-provisioner: 3 pods
- csi-resizer: 3 pods
- csi-snapshotter: 3 pods
- longhorn-csi-plugin: 8 pods (DaemonSet)
- engine-image: 8 pods (DaemonSet)

## Usage Examples

### Creating a PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 10Gi
```

### Using in a Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: my-app-data
```

## Troubleshooting

### Check Longhorn Status
```bash
kubectl -n longhorn-system get pods
kubectl get pv
kubectl get storageclass
```

### Access Logs
```bash
# Manager logs
kubectl -n longhorn-system logs -l app=longhorn-manager --tail=100

# CSI logs
kubectl -n longhorn-system logs -l app=csi-attacher --tail=50
```

### Common Issues

**Volume Degraded**:
- Check node status in Longhorn UI
- Wait for automatic rebuild (10-30 min per GB)
- Verify all nodes are healthy

**Pod Can't Mount Volume**:
- Check if volume is already attached to another pod
- Verify node has sufficient resources
- Check Longhorn manager logs

## Maintenance

### Prerequisites Installed
- nfs-common: via DaemonSet
- open-iscsi: via DaemonSet
- dm_crypt module: loaded via DaemonSet

### Monitoring
- **Metrics**: Disabled (enable when Prometheus operator is installed)
- **Grafana Dashboard**: ID 13032 (import when monitoring is set up)

## Next Steps

1. Change default password immediately
2. Configure backup target (S3 recommended)
3. Set up recurring backup jobs
4. Enable monitoring when Prometheus operator is available
5. Test disaster recovery procedures

For more details, see the [main Longhorn documentation](../../README.md).
