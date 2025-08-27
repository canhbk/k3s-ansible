# Longhorn Multi-Cluster Deployment

This directory contains the configuration and deployment scripts for Longhorn distributed storage system across multiple K3s clusters.

## Directory Structure

```
longhorn/
├── README.md                    # This file
├── base/                       # Base configuration shared across all clusters
│   ├── values-base.yaml        # Base Helm values
│   └── storageclass-base.yaml  # Base storage classes
├── clusters/                   # Cluster-specific configurations
│   ├── dev/                    # Development cluster
│   │   ├── values.yaml        # Dev-specific Helm values
│   │   └── ingress.yaml       # Dev-specific ingress
│   ├── vn/                     # Vietnam cluster
│   │   ├── values.yaml        # VN-specific Helm values
│   │   └── ingress.yaml       # VN-specific ingress
│   └── [other clusters...]    # Additional cluster configurations
├── scripts/                    # Deployment automation
│   └── deploy.sh              # Main deployment script
├── Makefile                    # Make targets for easy deployment
└── longhornctl                # Longhorn CLI tool (auto-downloaded)
```

## Prerequisites

Before deploying Longhorn, ensure:

1. **Cluster Access**: You have kubectl access to the target cluster
2. **Helm**: Helm 3.x is installed
3. **Storage**: Nodes have sufficient storage available
4. **Network**: Cluster nodes can communicate on required ports
5. **System Prerequisites**: Required packages installed on all nodes:
   - `open-iscsi` / `iscsid`
   - `nfs-common` (for NFS backups)
   - `cryptsetup` (for encrypted volumes)
   - `dm_crypt` kernel module

The deployment script will automatically:
- Download `longhornctl` CLI tool (v1.9.1)
- Check cluster prerequisites
- Deploy Longhorn using Helm

### Installing Missing Prerequisites

If prerequisites are missing, install them using Longhorn's official DaemonSets:

```bash
# Install NFS utilities
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.9.1/deploy/prerequisite/longhorn-nfs-installation.yaml

# Install iSCSI utilities
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.9.1/deploy/prerequisite/longhorn-iscsi-installation.yaml

# For dm_crypt module, create a DaemonSet to load it
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: enable-dm-crypt
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: enable-dm-crypt
  template:
    metadata:
      labels:
        name: enable-dm-crypt
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: enable-dm-crypt
        image: alpine
        command: ["nsenter", "--target", "1", "--mount", "--uts", "--ipc", "--net", "--pid", "--", "sh", "-c", "modprobe dm_crypt && echo 'dm_crypt module loaded' && sleep infinity"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: host-modules
          mountPath: /lib/modules
          readOnly: true
      volumes:
      - name: host-modules
        hostPath:
          path: /lib/modules
EOF
```

Wait for prerequisites to be installed before deploying Longhorn.

## Configuration

### Base Configuration

The `base/values-base.yaml` file contains common settings for all clusters:
- Longhorn version: **1.9.1**
- Default replica count: 3 (for multi-node clusters)
- CSI replica counts: 2 (for HA)
- Monitoring enabled by default

### Cluster-Specific Configuration

Each cluster has its own directory under `clusters/` with:
- `values.yaml`: Overrides for that specific cluster
- `ingress.yaml`: Cluster-specific ingress configuration

Example configurations:
- **Dev Cluster**: 2 replicas, no node restrictions
- **VN Cluster**: 1 replica, dedicated storage nodes with taints

## Deployment

### Using Make (Recommended)

```bash
# Deploy to dev cluster
make deploy-dev

# Deploy to vn cluster  
make deploy-vn

# Dry run (preview changes)
make dry-run-dev
make dry-run-vn

# Check deployment status
make status-dev
make status-vn

# Uninstall
make uninstall-dev
make uninstall-vn
```

### Using Deploy Script

```bash
# Deploy to a specific cluster
./scripts/deploy.sh -c dev

# Dry run mode
./scripts/deploy.sh -c vn -d

# Deploy specific version
./scripts/deploy.sh -c dev -v 1.9.0

# Show help
./scripts/deploy.sh -h
```

### Manual Deployment

```bash
# Switch to cluster context
kubectl config use-context dev

# Install prerequisites
./longhornctl install preflight

# Deploy using Helm
helm upgrade --install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --version 1.9.1 \
  -f base/values-base.yaml \
  -f clusters/dev/values.yaml

# Apply storage classes
kubectl apply -f base/storageclass-base.yaml

# Apply ingress
kubectl apply -f clusters/dev/ingress.yaml
```

## Access Longhorn UI

After deployment, access the Longhorn UI:

- **Dev**: https://dev.longhorn.canhnv.com
- **VN**: https://vn.longhorn.canhnv.com
- **[Other clusters]**: https://[cluster].longhorn.canhnv.com

Default credentials (basic auth):
- Username: `admin`
- Password: `admin`

**Important**: Change the default password immediately after deployment!

## Storage Classes

Three storage classes are provided:

1. **longhorn** (default)
   - Reclaim Policy: Delete
   - Replicas: 3 (or cluster-specific)
   
2. **longhorn-retain**
   - Reclaim Policy: Retain
   - Replicas: 3 (or cluster-specific)
   - Use for important data

3. **longhorn-fast**
   - Reclaim Policy: Delete
   - Replicas: 2
   - Data Locality: best-effort
   - Use for performance-sensitive workloads

## Adding New Clusters

To add support for a new cluster:

1. Create cluster directory:
   ```bash
   mkdir -p clusters/[cluster-name]
   ```

2. Create cluster-specific values:
   ```bash
   cp clusters/dev/values.yaml clusters/[cluster-name]/values.yaml
   # Edit values.yaml as needed
   ```

3. Create cluster-specific ingress:
   ```bash
   cp clusters/dev/ingress.yaml clusters/[cluster-name]/ingress.yaml
   # Update hostname and other settings
   ```

4. Update Makefile to add deployment targets

## Troubleshooting

### Check Prerequisites
```bash
./longhornctl check preflight
```

### View Longhorn Pods
```bash
kubectl -n longhorn-system get pods
```

### Check Longhorn Logs
```bash
kubectl -n longhorn-system logs -l app=longhorn-manager
```

### Storage Class Issues
```bash
kubectl get storageclass
kubectl describe storageclass longhorn
```

## Maintenance

### Upgrade Longhorn
1. Update `CHART_VERSION` in Makefile and deploy.sh
2. Update image tags in base/values-base.yaml
3. Run deployment for each cluster

### Backup Configuration
Regular backups should be configured in Longhorn UI or via backup target settings.

## References

- [Longhorn Documentation](https://longhorn.io/docs/1.9.1/)
- [Longhorn GitHub](https://github.com/longhorn/longhorn)
- [Helm Chart Values](https://github.com/longhorn/charts/blob/master/charts/longhorn/values.yaml)