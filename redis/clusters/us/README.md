# Redis Deployment - US Cluster

This directory contains Redis deployment configurations for the US cluster.

## Current Deployment Status

- **Type**: Standalone Redis deployment
- **Namespace**: `redis`
- **Storage**: Longhorn local storage with 2Gi PVC
- **Architecture**: Single instance setup

## Resources

### Deployed Resources

#### Redis Instance

- **Deployment**: `redis` (1/1 replicas)
- **Service**: `redis` (ClusterIP: 10.47.6.102:6379)
- **Image**: redis:8.0.3-alpine
- **Authentication**: Password-based via `redis-password-secret`

#### RedisInsight (Management UI)

- **Deployment**: `redisinsight` (1/1 replicas)
- **Service**: `redisinsight-service` (LoadBalancer)
- **External IPs**: 64.71.161.44, 65.49.60.35, 74.82.63.155
- **Port**: 80 (NodePort: 32079)
- **Authentication**: Basic auth via `basic-auth` secret
- **Preconfigured Connection**: `redis.redis.svc.cluster.local:6379`

### Secrets

- `redis-password-secret` - Redis authentication password
- `basic-auth` - HTTP basic auth for RedisInsight

## Files

- `standalone.yaml` - Standalone Redis deployment with Longhorn local storage
- `redisinsight.yaml` - RedisInsight deployment with preconfigured connections

## Deployment

```bash
# Switch to US cluster context
kubectl config use-context us

# Deploy Redis
kubectl apply -f standalone.yaml

# Deploy RedisInsight
kubectl apply -f redisinsight.yaml
```

## RedisInsight Access

Access the web UI via the domain `https://redis.us.canhnv.com`.
Authentication is required using the credentials stored in the `basic-auth` secret.

### Preconfigured Database Connection

RedisInsight is automatically configured with the following Redis connection:

**Redis Standalone** (ID: 0)
- Host: `redis.redis.svc.cluster.local`
- Port: `6379`
- Username: `default`
- Password: Automatically retrieved from `redis-password-secret`

This connection is configured via environment variables and will be available immediately upon accessing RedisInsight.

## Documentation

For detailed information about Redis deployment, access, and management, see:

- [Redis Documentation](../../../docs/clusters/us/REDIS.md)

## Storage

This deployment uses `longhorn-local` storage class for optimal performance with strict local data locality.
