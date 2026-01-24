# Redis Deployments

This directory contains Redis deployment configurations for different K3s clusters.

## Directory Structure

```
redis/
├── clusters/           # Cluster-specific deployments
│   ├── vn/            # VN cluster (standalone deployment)
│   │   ├── README.md
│   │   └── standalone.yaml
│   └── dev/           # Dev cluster (Helm-based deployment)
│       ├── README.md
│       ├── values.yaml
│       ├── redisinsight.yaml
│       └── oauth2-proxy/
├── common/            # Shared scripts and examples
│   ├── auth.example
│   └── delete-redis-cluster-pvs.sh
├── examples/          # Example configurations
└── .gitignore         # Excludes sensitive files
```

## Cluster Deployments

### VN Cluster
- **Type**: Standalone Redis (single instance)
- **Method**: Direct YAML manifest
- **Details**: See [clusters/vn/README.md](clusters/vn/README.md)

### Dev Cluster
- **Type**: Redis cluster with master-replica architecture
- **Method**: Bitnami Helm chart
- **Includes**: RedisInsight management UI
- **Details**: See [clusters/dev/README.md](clusters/dev/README.md)

## General Setup Guide

## Prerequisites

- Kubernetes cluster running
- Helm installed and configured
- kubectl configured to access your cluster

## Common Setup Steps

### Add Bitnami Helm Repository

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### Create Namespace and Secrets

Create a dedicated namespace for Redis:

```bash
kubectl create namespace redis
```

Create a secret to store the Redis password:

```bash
kubectl create secret generic redis-password-secret \
  --namespace redis \
  --from-literal=redis-password="wcduuh69TXJbbuMprAYz"
```

### Install Redis

Deploy the Redis using your custom values file:

```bash
helm install my-redis bitnami/redis --namespace redis -f values.yaml
```

## Managing the Deployment

### Update Configuration

To redeploy with updated values:

```bash
helm upgrade --install my-redis bitnami/redis --namespace redis -f values.yaml
```

### Complete Removal

To fully uninstall Redis and clean up storage:

1. **Uninstall the Helm release:**

   ```bash
   helm uninstall my-redis --namespace redis
   ```

2. **Remove persistent volumes:**
PVC and PVC are auto delete when uninstall. Bellow are manually command to remove PV and PVC

   ```bash
   kubectl delete pvc --all
   ./delete-redis-cluster-pvs.sh
   ```

3. **Clean up storage backend:**
   After deleting persistent volumes, remove any detached volumes in the Longhorn Dashboard to completely free allocated storage.

## Verification and Testing

### Access Redis Cluster

Connect to the Redis cluster directly:

```bash
kubectl exec -it my-redis-master-0 -n redis -- \
  redis-cli -c -a superSecurePass123
```

### Cluster Health Commands

Once connected to the Redis CLI, verify cluster status:

```bash
cluster info
cluster nodes
```

## Redis Management GUI

### Install RedisInsight

Deploy RedisInsight:

htpasswd -nb admin your-password > auth
kubectl -n redis create secret generic basic-auth --from-file=auth

```bash
printf "%s" "$(htpasswd -nb admin your-password)" > auth
```

### Access RedisInsight

Forward the port for local access:

```bash
kubectl port-forward --address=0.0.0.0 deployment/redisinsight 5540
```

For remote access, configure Tailscale or your preferred networking solution.

### Connect to Redis

Configure RedisInsight with these connection details:

- **Host:** `my-redis-master.redis.svc.cluster.local`
- **Port:** `6379` (default)
- **Password:** `superSecurePass123`

**Note:** The host uses one of the three master Redis nodes' internal DNS names for cluster connectivity.

## Security Considerations

- Change the default password (`superSecurePass123`) to a strong, unique password
- Consider using Kubernetes secrets management tools for password rotation
- Restrict network access to Redis cluster using NetworkPolicies if needed
- Enable TLS encryption for production deployments

## Troubleshooting

### Common Issues

#### Permission Denied Error (Fixed in standalone.yaml)
If you encounter the error:
```
MISCONF Redis is configured to save RDB snapshots, but it's currently unable to persist to disk
```

This indicates Redis cannot write to its data directory. The standalone deployment includes the proper security context to prevent this issue. If using a custom deployment, ensure you include the security context settings described above.

#### General Troubleshooting Steps
- Verify all pods are running: `kubectl get pods -n redis`
- Check pod logs: `kubectl logs <pod-name> -n redis`
- Ensure storage classes are properly configured for persistent volumes
- Confirm network connectivity between RedisInsight and Redis cluster
- Check Redis can save RDB snapshots: `kubectl exec -it <redis-pod> -n redis -- redis-cli BGSAVE`

helm repo add oauth2-proxy <https://oauth2-proxy.github.io/manifests>

helm install oauth2-proxy-release oauth2-proxy/oauth2-proxy --namespace redis -f oauth2-proxy/values.yaml
