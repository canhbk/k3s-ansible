# RustFS Storage Migration Log - SG3 Cluster

## Migration: local-path to Longhorn (2025-01-28)

### Summary

Migrated RustFS storage from `local-path` storage class to `longhorn` for improved data resilience and distributed replication.

### Before

| Property | Value |
|----------|-------|
| Storage Class | local-path |
| Data PVC Size | 256Mi |
| Logs PVC Size | 256Mi |
| Data Replicas | Single node |
| Buckets | .rustfs.sys, clotheshop-alpha, numerology |
| Total Data | ~632K |

### After

| Property | Value |
|----------|-------|
| Storage Class | longhorn |
| Data PVC Size | 15Gi |
| Logs PVC Size | 1Gi |
| Data Replicas | 3 (Longhorn distributed) |
| Buckets | (recreated on demand) |

### Changes Made

1. **values.yaml**: Fixed Helm chart parameter from `persistence.storageClass` to `storageclass.name`
2. **PVCs**: Deleted old local-path PVCs and created new Longhorn PVCs
3. **Data**: Existing buckets were removed (minimal data, can be recreated)

### Helm Chart Issue

The RustFS Helm chart has a non-standard configuration pattern. It uses:

```yaml
# Correct (what the chart expects)
storageclass:
  name: longhorn
  dataStorageSize: 15Gi
  logStorageSize: 1Gi

# Incorrect (common convention, but NOT supported)
persistence:
  storageClass: longhorn
  size: 15Gi
```

### Verification Commands

```bash
# Check PVCs
kubectl get pvc -n rustfs -o wide

# Check Longhorn volumes
kubectl get volume -n longhorn-system | grep rustfs

# Check pod status
kubectl get pods -n rustfs

# Test endpoints
curl -I https://rustfs.sg3.canhnv.com
curl -I https://rustfs-console.sg3.canhnv.com
```

### Rollback Procedure

If needed, rollback by reinstalling with local-path:

```bash
helm uninstall rustfs -n rustfs
kubectl delete pvc -n rustfs --all

# Edit values.yaml to use local-path
helm install rustfs rustfs/rustfs -n rustfs -f values.yaml
kubectl apply -f ingress.yaml
```
