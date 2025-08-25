# Longhorn Storage - US Cluster

## Overview

Longhorn v1.9.1 is deployed on the US cluster to provide distributed block storage for Kubernetes workloads. The US cluster consists of 2 nodes, requiring specific configuration optimizations for storage redundancy and performance.

## Cluster Information

- **Cluster Name**: us
- **Cluster Context**: `us`
- **API Endpoint**: <https://65.49.60.35:6443>
- **Environment**: Production
- **Region**: North America
- **Nodes**: 2 (1 control-plane + 1 worker)
  - vps26-optimal-us (control-plane, etcd, master)
  - vps27-optimal-us (worker)

## Deployment Status

✅ **Deployed Successfully** - August 25, 2025

### Component Status

All Longhorn components are running and healthy:

- **Manager Pods**: 2/2 Running
- **UI Pod**: 1/1 Running
- **CSI Driver**: Deployed on both nodes
- **Engine Image**: Available on both nodes
- **Instance Managers**: Running on both nodes

## Storage Classes

The US cluster provides optimized storage classes for the 2-node configuration:

### 1. **longhorn-replicated** (Default)

- **Replicas**: 2 (full redundancy across both nodes)
- **Reclaim Policy**: Delete
- **Data Locality**: Disabled
- **Use Case**: General workloads requiring high availability

### 2. **longhorn-local**

- **Replicas**: 1 (single copy for performance)
- **Reclaim Policy**: Delete
- **Data Locality**: strict-local (pod scheduled on same node as data)
- **Use Case**: Performance-critical workloads (Redis, databases)

### 3. **longhorn-replicated-retain**

- **Replicas**: 2
- **Reclaim Policy**: Retain
- **Data Locality**: Disabled
- **Use Case**: Important data that must persist after PVC deletion

### Additional Storage Classes (from base)

- **longhorn**: Standard storage class with Retain policy
- **longhorn-static**: For static volume provisioning

## Access Information

### Web UI

- **URL**: <https://us.longhorn.canhnv.com>
- **Authentication**: Basic Auth
- **Default Credentials**:
  - Username: `admin`
  - Password: `admin`

⚠️ **IMPORTANT**: Change the default password immediately after first login!

### Ingress Configuration

- **Ingress Class**: Traefik
- **TLS**: Enabled (cert-manager with Let's Encrypt staging)
- **Middleware**: Basic authentication

## Configuration Details

### Helm Values Override

Located at: `clusters/us/values.yaml`

Key configurations:

- CSI replica counts set to 1 (2-node cluster limitation)
- Default replica count: 2 for data redundancy
- UI replicas: 1
- Metrics enabled with cluster labels

### Prerequisites Installed

- ✅ iSCSI tools (open-iscsi/iscsid)
- ✅ NFSv4 support
- ✅ Cryptsetup tools
- ✅ Device mapper tools

### Known Warnings

- multipathd.service is running (monitor for potential issues)
- CoreDNS running with single replica (K3s default)

## Usage Examples

### Creating a Replicated Volume

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-storage
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn-replicated
  resources:
    requests:
      storage: 10Gi
```

### Creating a Local Performance Volume

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn-local
  resources:
    requests:
      storage: 5Gi
```

## Maintenance Operations

### Check Status

```bash
make status-us
```

### View Logs

```bash
kubectl -n longhorn-system logs -l app=longhorn-manager
```

### Access UI via Port Forward (Alternative)

```bash
kubectl -n longhorn-system port-forward svc/longhorn-frontend 8080:80
# Access at http://localhost:8080
```

### Upgrade Longhorn

```bash
# Update CHART_VERSION in Makefile
make deploy-us
```

### Uninstall

```bash
make uninstall-us
```

### Update Password

Two scripts are available to update the Longhorn UI password:

#### Option 1: Using update-password.sh (requires htpasswd)

```bash
# Interactive password prompt
./scripts/update-password.sh -c us

# Set specific password
./scripts/update-password.sh -c us -u admin -p newpassword

# Generate random secure password
./scripts/update-password.sh -c us -g
```

#### Option 2: Using update-password-simple.sh (uses Docker)

```bash
# Update password for admin user
./scripts/update-password-simple.sh us

# Update password for specific user
./scripts/update-password-simple.sh us johndoe
```

## Best Practices

1. **Volume Replicas**:
   - Use 2 replicas for critical data (longhorn-replicated)
   - Use 1 replica with local binding for performance-critical workloads

2. **Monitoring**:
   - Monitor disk space on both nodes regularly
   - Check volume health in Longhorn UI
   - Set up alerts for volume degradation

3. **Backups**:
   - Configure backup target (S3/NFS) for critical data
   - Schedule regular snapshots for important volumes

4. **Maintenance Windows**:
   - With only 2 nodes, plan maintenance carefully
   - Consider using `longhorn-local` volumes for workloads that can tolerate downtime

## Troubleshooting

### Common Issues

1. **Pod Cannot Attach Volume**
   - Check if volume is already attached to another node
   - Verify node health in Longhorn UI
   - Check instance manager logs

2. **Volume Stuck in Degraded State**
   - With 2 replicas on 2 nodes, losing one node causes degradation
   - Check node connectivity
   - May need to force detach/reattach

3. **Performance Issues**
   - Consider using `longhorn-local` storage class
   - Check network latency between nodes
   - Monitor CPU/memory usage on instance managers

### Support Commands

```bash
# Check volume status
kubectl -n longhorn-system get volumes.longhorn.io

# Check engine status
kubectl -n longhorn-system get engines.longhorn.io

# View replicas
kubectl -n longhorn-system get replicas.longhorn.io
```

## Security Considerations

1. **Change default credentials immediately**
2. **Consider upgrading to production TLS certificate** (currently using staging)
3. **Restrict access to Longhorn UI** via network policies if needed
4. **Regular security updates** for Longhorn components

## References

- [Longhorn Documentation](https://longhorn.io/docs/1.9.1/)
- [Project Deployment Guide](../../README.md)
- [Cluster Overview](../../../../docs/CLUSTERS_OVERVIEW.md)
