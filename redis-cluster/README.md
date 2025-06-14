# Redis Cluster Setup Guide

This guide walks through setting up a Redis cluster using Helm and Bitnami charts in Kubernetes.

## Prerequisites

- Kubernetes cluster running
- Helm installed and configured
- kubectl configured to access your cluster

## Initial Setup

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
  --from-literal=redis-password="superSecurePass123"
```

### Install Redis Cluster

Deploy the Redis cluster using your custom values file:

```bash
helm install my-redis bitnami/redis-cluster --namespace redis -f values.yaml
```

## Managing the Deployment

### Update Configuration

To redeploy with updated values:

```bash
helm upgrade --install my-redis bitnami/redis-cluster --namespace redis -f values.yaml
```

### Complete Removal

To fully uninstall Redis and clean up storage:

1. **Uninstall the Helm release:**

   ```bash
   helm uninstall my-redis --namespace redis
   ```

2. **Remove persistent volumes:**

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
kubectl exec -it my-redis-redis-cluster-0 -n redis -- \
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

Add the RedisInsight Helm repository:

```bash
helm repo add redisinsight https://charts.redis.com
```

Deploy RedisInsight:

```bash
kubectl apply -f redisinsight.yaml
```

### Access RedisInsight

Forward the port for local access:

```bash
kubectl port-forward --address=0.0.0.0 deployment/redisinsight 5540
```

For remote access, configure Tailscale or your preferred networking solution.

### Connect to Redis Cluster

Configure RedisInsight with these connection details:

- **Host:** `my-redis-redis-cluster-0.my-redis-redis-cluster-headless.redis.svc.cluster.local`
- **Port:** `6379` (default)
- **Password:** `superSecurePass123`

**Note:** The host uses one of the three master Redis nodes' internal DNS names for cluster connectivity.

## Security Considerations

- Change the default password (`superSecurePass123`) to a strong, unique password
- Consider using Kubernetes secrets management tools for password rotation
- Restrict network access to Redis cluster using NetworkPolicies if needed
- Enable TLS encryption for production deployments

## Troubleshooting

- Verify all pods are running: `kubectl get pods -n redis`
- Check pod logs: `kubectl logs <pod-name> -n redis`
- Ensure storage classes are properly configured for persistent volumes
- Confirm network connectivity between RedisInsight and Redis cluster
