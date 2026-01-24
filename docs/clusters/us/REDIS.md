# Redis Standalone - US Cluster

## Overview

Redis standalone instance is deployed on the US cluster to provide in-memory caching and data storage for applications. This deployment uses Longhorn local storage for data persistence.

## Deployment Information

- **Namespace**: redis
- **Deployment Type**: Standalone (single instance)
- **Redis Version**: 8.0.3-alpine
- **Storage**: 2Gi Longhorn local volume
- **Storage Class**: longhorn-local (single replica, strict local data locality)
- **Node**: Scheduled on vps27-optimal-us

## Access Information

### Internal Access (Within Cluster)

- **Service Name**: redis.redis.svc.cluster.local
- **Port**: 6379
- **Authentication**: Password required

### Connection Examples

#### From within a pod in the cluster

```bash
# Using redis-cli
redis-cli -h redis.redis.svc.cluster.local -p 6379 -a '<password>'

# Connection string
redis://:<password>@redis.redis.svc.cluster.local:6379

# For applications in the same namespace
redis://:<password>@redis:6379
```

#### Test connection

```bash
kubectl run -it --rm redis-cli --image=redis:8.0.3-alpine --restart=Never -- \
  redis-cli -h redis.redis.svc.cluster.local -a '<password>' ping
```

## Security

### Authentication

Redis is configured with password authentication. The password is stored in a Kubernetes secret:

- **Secret Name**: redis-password-secret
- **Secret Key**: redis-password
- **Namespace**: redis

To retrieve the password:

```bash
kubectl get secret redis-password-secret -n redis -o jsonpath='{.data.redis-password}' | base64 -d
```

### Security Context

The Redis pod runs with the following security settings:

- Non-root user (UID 999)
- Read-only root filesystem disabled (required for Redis data persistence)
- All capabilities dropped
- No privilege escalation allowed

## Storage Configuration

### Longhorn Local Storage

This deployment uses `longhorn-local` storage class which provides:

- **Single replica**: Optimized for performance
- **Strict local data locality**: Pod is always scheduled on the same node as its data
- **Persistent storage**: Data survives pod restarts
- **2Gi volume size**: Can be expanded if needed

### Data Persistence

Redis is configured with default persistence settings:

- **RDB snapshots**: Enabled (automatic snapshots based on write operations)
- **AOF (Append Only File)**: Can be enabled if needed for better durability

## Resource Allocation

### Requests

- Memory: 1Gi
- CPU: 300m
- Ephemeral Storage: 1Gi

### Limits

- Memory: 2Gi
- CPU: 1 core
- Ephemeral Storage: 2Gi

## Health Checks

### Liveness Probe

- Type: TCP Socket
- Port: 6379
- Initial Delay: 15 seconds
- Period: 20 seconds

### Readiness Probe

- Type: TCP Socket
- Port: 6379
- Initial Delay: 5 seconds
- Period: 10 seconds

## Maintenance Operations

### Check Redis Status

```bash
# Check pod status
kubectl get pod -n redis

# Check logs
kubectl logs -n redis -l app=redis

# Check PVC status
kubectl get pvc -n redis

# Check volume in Longhorn UI
# Visit: https://us.longhorn.canhnv.com
```

### Connect to Redis Pod

```bash
kubectl exec -it -n redis deployment/redis -- redis-cli -a '<password>'
```

### Common Redis Commands

```bash
# Check Redis info
INFO

# Check memory usage
INFO memory

# List all keys (use with caution in production)
KEYS *

# Check persistence status
CONFIG GET save
CONFIG GET appendonly
```

### Restart Redis

```bash
kubectl rollout restart deployment/redis -n redis
```

### Scale Operations

As this is a standalone deployment, scaling is not recommended. For high availability, consider deploying Redis in cluster mode or using Redis Sentinel.

## Backup and Recovery

### Manual Backup

```bash
# Create a backup of Redis data
kubectl exec -n redis deployment/redis -- redis-cli -a '<password>' BGSAVE

# Copy the dump file
kubectl cp redis/<pod-name>:/data/dump.rdb ./redis-backup-$(date +%Y%m%d-%H%M%S).rdb
```

### Restore from Backup

1. Scale down the deployment:

   ```bash
   kubectl scale deployment/redis -n redis --replicas=0
   ```

2. Copy backup file to the volume (requires access to the node or a temporary pod)

3. Scale up the deployment:

   ```bash
   kubectl scale deployment/redis -n redis --replicas=1
   ```

## Monitoring

### Key Metrics to Monitor

- Memory usage (should stay below 2Gi limit)
- CPU usage
- Network connections
- Command statistics
- Evicted keys (indicates memory pressure)

### Example Monitoring Commands

```bash
# Memory stats
kubectl exec -n redis deployment/redis -- redis-cli -a '<password>' INFO memory

# Client connections
kubectl exec -n redis deployment/redis -- redis-cli -a '<password>' CLIENT LIST

# Command statistics
kubectl exec -n redis deployment/redis -- redis-cli -a '<password>' INFO commandstats
```

## Troubleshooting

### Common Issues

1. **Pod fails to start**
   - Check PVC is bound: `kubectl get pvc -n redis`
   - Check pod events: `kubectl describe pod -n redis -l app=redis`
   - Check logs: `kubectl logs -n redis -l app=redis`

2. **Connection refused**
   - Verify service is running: `kubectl get svc -n redis`
   - Check if pod is ready: `kubectl get pod -n redis`
   - Ensure using correct password

3. **Out of memory**
   - Check memory usage: `kubectl exec -n redis deployment/redis -- redis-cli -a '<password>' INFO memory`
   - Consider increasing memory limits or implementing eviction policies
   - Review stored data and implement TTLs where appropriate

4. **Performance issues**
   - Redis is using longhorn-local which provides good performance
   - Check if the node (vps27-optimal-us) has sufficient resources
   - Monitor disk I/O on the node

## Configuration File Location

The deployment manifest is located at:

```
/k3s-ansible/redis/clusters/us/standalone.yaml
```

## Updates and Upgrades

To update Redis version:

1. Update the image tag in the deployment manifest
2. Apply the changes: `kubectl apply -f redis/clusters/us/standalone.yaml`
3. Monitor the rollout: `kubectl rollout status deployment/redis -n redis`

## Security Best Practices

1. **Regular password rotation**: Update the redis-password-secret periodically
2. **Network policies**: Consider implementing network policies to restrict access
3. **Monitoring**: Set up alerts for suspicious activities
4. **Updates**: Keep Redis image updated with security patches
5. **Backups**: Implement regular backup procedures for critical data

## Related Documentation

- [Redis Official Documentation](https://redis.io/documentation)
- [Longhorn Storage - US Cluster](../../../longhorn/clusters/us/README.md)
- [Cluster Overview](../../CLUSTERS_OVERVIEW.md)
