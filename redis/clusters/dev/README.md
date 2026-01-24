# Redis Deployment - Dev Cluster

## Current Deployment Status

- **Type**: Redis cluster via Bitnami Helm chart
- **Namespace**: `redis`
- **Deployment Method**: Helm (chart: bitnami/redis v21.2.5)
- **Architecture**: Master-Replica setup
- **Storage**: Longhorn PVCs

## Resources

### Deployed Resources

#### Redis Cluster (Helm Release: my-redis)

- **Master**: 1 instance with 2Gi storage
- **Replicas**: 3 instances with 2Gi storage each
- **Services**:
  - `my-redis-master` (ClusterIP: 10.43.230.90:6379)
  - `my-redis-replicas` (ClusterIP: 10.43.202.127:6379)
  - `my-redis-headless` (Headless service for StatefulSet)

#### RedisInsight (Management UI)

- **Deployment**: `redisinsight` (1/1 replicas)
- **Service**: `redisinsight-service` (LoadBalancer)
- **External IPs**: Will be reassigned after cluster redeployment (updated 2025-11-24)
  - Expected new IPs: 180.93.96.54, 180.93.96.10, 180.93.96.15, 180.93.96.101, 160.191.245.234, 160.191.245.244
- **Port**: 80 (NodePort: 32090)
- **Authentication**: Basic auth via `basic-auth` secret
- **Preconfigured Connections**:
  - Redis Master: `my-redis-master.redis.svc.cluster.local:6379`
  - Redis Replicas: `my-redis-replicas.redis.svc.cluster.local:6379`

### Secrets

- `redis-password-secret` - Redis authentication password
- `basic-auth` - HTTP basic auth for RedisInsight

### Configuration Files

- `values.yaml` - Helm values for Redis deployment
- `redisinsight.yaml` - RedisInsight deployment manifest

## Deployment Commands

```bash
# Deploy Redis cluster
helm upgrade --install my-redis bitnami/redis --namespace redis -f values.yaml

# Check Helm release
helm list -n redis

# Check all resources
kubectl get all -n redis

# Access Redis master
kubectl exec -it my-redis-master-0 -n redis -- redis-cli -a $(kubectl get secret redis-password-secret -n redis -o jsonpath='{.data.redis-password}' | base64 -d)
```

## RedisInsight Access

Access the web UI at any of the external IPs on port 80 or via the domain `https://redis.canhnv.com`.
Authentication is required using the credentials stored in the `basic-auth` secret.

### Preconfigured Database Connections

RedisInsight is automatically configured with the following Redis connections:

1. **Redis Master** (ID: 0)
   - Host: `my-redis-master.redis.svc.cluster.local`
   - Port: `6379`
   - Username: `default`
   - Password: Automatically retrieved from `redis-password-secret`

2. **Redis Replicas** (ID: 1)
   - Host: `my-redis-replicas.redis.svc.cluster.local`
   - Port: `6379`
   - Username: `default`
   - Password: Automatically retrieved from `redis-password-secret`

These connections are configured via environment variables and will be available immediately upon accessing RedisInsight.

## Node Affinity

Both master and replica pods have:

- Toleration for `dedicated=storage:NoSchedule` taint
- Preference for nodes with `role=storage` label
