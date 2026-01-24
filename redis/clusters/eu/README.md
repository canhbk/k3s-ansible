# Redis Standalone Deployment - EU Cluster

## Overview

This deployment creates a standalone Redis instance on the EU cluster with strict data locality for maximum performance.

## Key Features

- **Storage**: Uses `longhorn-local` storage class with `dataLocality: "strict-local"`
- **Performance**: Redis pod runs on the same node as its volume (zero network latency)
- **Security**: Password authentication via Kubernetes secret
- **Resources**: 1-2Gi memory, 300m-1 CPU

## Prerequisites

1. Create namespace and secret:
```bash
kubectl config use-context eu
kubectl create namespace redis
kubectl create secret generic redis-password-secret \
  --from-literal=redis-password='<your-secure-password>' \
  -n redis
```

## Deployment

```bash
kubectl apply -f standalone.yaml
```

## Verify Data Locality

Ensure Redis pod is running on the same node as its volume:

```bash
# Check which node the PV is on
kubectl get pv -o wide | grep redis

# Verify the pod is on the same node
kubectl get pods -n redis -o wide
```

## Access

### From within cluster:
- Host: `redis.redis.svc.cluster.local`
- Port: `6379`
- Password: Retrieved from secret

### Connection string format:
```
redis://:$PASSWORD@redis.redis.svc.cluster.local:6379
```

### Example connection from another pod:
```bash
# Get password
export REDIS_PASSWORD=$(kubectl get secret redis-password-secret -n redis -o jsonpath='{.data.redis-password}' | base64 -d)

# Connect using redis-cli
redis-cli -h redis.redis.svc.cluster.local -p 6379 -a $REDIS_PASSWORD
```

## Important Notes

- Data locality is strictly enforced - the pod can only run on the node where the volume exists
- This provides maximum performance but less scheduling flexibility
- If the node with the volume fails, Redis will not be able to reschedule until the node recovers

## Monitoring

Check Redis pod status:
```bash
kubectl get pods -n redis
kubectl logs -n redis deployment/redis
```