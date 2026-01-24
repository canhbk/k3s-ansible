# Redis Standalone - SG3 Cluster

## Overview

Standalone Redis instance deployed on the SG3 cluster for caching and data storage.

## Deployment Details

- **Cluster**: sg3
- **Namespace**: redis
- **Storage Class**: longhorn
- **Storage Size**: 2Gi
- **Redis Version**: 8.0.3-alpine
- **Deployment Date**: 2025-11-25

## Resources

### Service
- **Name**: redis
- **Type**: ClusterIP
- **Internal IP**: 10.55.20.98
- **Port**: 6379

### Storage
- **PVC Name**: redis-data
- **Storage Class**: longhorn
- **Capacity**: 2Gi
- **Access Mode**: ReadWriteOnce

## Connection Information

### From within the cluster:
```bash
Host: redis.redis.svc.cluster.local
Port: 6379
Password: <stored in redis-password-secret>
```

### Connection String:
```
redis://:PASSWORD@redis.redis.svc.cluster.local:6379
```

### Get Password:
```bash
kubectl get secret redis-password-secret -n redis -o jsonpath='{.data.redis-password}' | base64 -d
```

## Resource Allocation

### Requests:
- Memory: 1Gi
- CPU: 300m
- Ephemeral Storage: 1Gi

### Limits:
- Memory: 2Gi
- CPU: 1 core
- Ephemeral Storage: 2Gi

## Security

- Runs as non-root user (UID 999)
- Password authentication enabled
- All capabilities dropped
- Read-only root filesystem disabled (Redis needs write access to /data)

## Health Checks

- **Liveness Probe**: TCP socket on port 6379, checks every 20s after 15s initial delay
- **Readiness Probe**: TCP socket on port 6379, checks every 10s after 5s initial delay

## Testing Connection

```bash
# Test from within cluster
kubectl exec -n redis deployment/redis -- redis-cli -a "$(kubectl get secret redis-password-secret -n redis -o jsonpath='{.data.redis-password}' | base64 -d)" ping

# Expected output: PONG
```

## Deployment Commands

```bash
# Switch to sg3 context
kubectl config use-context sg3

# Create namespace (if not exists)
kubectl create namespace redis

# Create password secret
kubectl create secret generic redis-password-secret \
  --from-literal=redis-password='YOUR_PASSWORD_HERE' \
  -n redis

# Deploy Redis
kubectl apply -f redis/clusters/sg3/standalone.yaml

# Verify deployment
kubectl get all -n redis
kubectl get pvc -n redis
```

## Maintenance

### Check Logs
```bash
kubectl logs -n redis deployment/redis -f
```

### Restart Redis
```bash
kubectl rollout restart deployment/redis -n redis
```

### Scale (for testing only - standalone should always be 1)
```bash
kubectl scale deployment/redis -n redis --replicas=1
```

### Backup Data
```bash
# Trigger Redis save
kubectl exec -n redis deployment/redis -- redis-cli -a "PASSWORD" BGSAVE

# Check backup status
kubectl exec -n redis deployment/redis -- redis-cli -a "PASSWORD" LASTSAVE
```

## Monitoring

### Check Memory Usage
```bash
kubectl exec -n redis deployment/redis -- redis-cli -a "PASSWORD" INFO memory
```

### Check Stats
```bash
kubectl exec -n redis deployment/redis -- redis-cli -a "PASSWORD" INFO stats
```

## Troubleshooting

### Pod Not Starting
```bash
# Check pod events
kubectl describe pod -n redis -l app=redis

# Check PVC status
kubectl get pvc -n redis

# Check Longhorn volumes
kubectl get volumes -n longhorn-system
```

### Connection Issues
```bash
# Test from another pod
kubectl run -it --rm redis-test --image=redis:8.0.3-alpine --restart=Never -- redis-cli -h redis.redis.svc.cluster.local -a "PASSWORD" ping
```

### Performance Issues
```bash
# Check slow log
kubectl exec -n redis deployment/redis -- redis-cli -a "PASSWORD" SLOWLOG GET 10

# Check client list
kubectl exec -n redis deployment/redis -- redis-cli -a "PASSWORD" CLIENT LIST
```
