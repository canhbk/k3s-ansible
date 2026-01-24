# Redis Deployment - VN Cluster

## Current Deployment Status

- **Type**: Standalone Redis deployment
- **Namespace**: `redis`
- **Deployment Method**: Direct YAML manifest
- **Storage**: Longhorn PVC (2Gi)
- **Replicas**: 1

## Resources

### Deployed Resources
- **Deployment**: `redis` (1/1 replicas)
- **Service**: `redis` (ClusterIP: 10.43.16.121:6379)
- **PVC**: `redis-data` (2Gi, longhorn-vn storage class)
- **Secret**: `redis-password-secret` (contains Redis password)

### Configuration Files
- `standalone.yaml` - Main deployment manifest with security context fixes

## Deployment Commands

```bash
# Deploy Redis
kubectl apply -f standalone.yaml

# Check status
kubectl get all -n redis

# Test connection
kubectl exec -it deploy/redis -n redis -- redis-cli -a $(kubectl get secret redis-password-secret -n redis -o jsonpath='{.data.redis-password}' | base64 -d) ping
```

## Security Context

The deployment includes proper security context to prevent permission issues:
- Pod runs as user 999 (redis user)
- fsGroup set to 999 for volume permissions
- Non-root execution enforced
- All capabilities dropped

## Node Affinity

Pods are scheduled with:
- Toleration for `dedicated=storage:NoSchedule` taint
- Preference for nodes with `role=storage` label