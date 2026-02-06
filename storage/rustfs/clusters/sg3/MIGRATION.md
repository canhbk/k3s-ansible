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

## Incident: I/O Error Recovery (2026-02-06)

### Summary

RustFS on `rustfs.sg3.canhnv.com` returned `InternalError: I/O error (os error 5)` for all object operations due to two compounding storage failures.

### Root Causes

1. **Data Volume FAULTED**: Longhorn volume `pvc-d6d352d9-01a8-47cf-9369-be367ff5741f` (15Gi, 1 replica) had its single replica fail on vps53 due to disk pressure. Auto-salvage was stuck in an infinite loop because `salvageExecuted: true` was already set with 0 eligible replicas.

2. **Logs Volume 100% Full**: `rustfs-logs` PVC (1Gi) was at 958M/974M. Logger failures cascaded into bloom filter and config write failures.

### Recovery Steps Taken

1. **Reduced Longhorn `storageReserved`** on vps53 from 30Gi to 10Gi to resolve DiskPressure scheduling condition
2. **Reset replica failure state** via kubectl patch:
   ```bash
   kubectl -n longhorn-system patch replicas.longhorn.io \
     pvc-d6d352d9-01a8-47cf-9369-be367ff5741f-r-def86db8 \
     --type=merge -p '{"spec":{"failedAt":"","lastFailedAt":"","salvageRequested":false}}'
   ```
3. **Cleared logs volume**: Truncated all log files to free 958MB
4. **Pod restart**: Fresh pod with clean volume mounts

### Prevention Changes

- **`logStorageSize`**: Increased from `1Gi` to `5Gi` in `values.yaml`
- **Longhorn replica count**: Should be increased from 1 to 2 once disk pressure is resolved across nodes

### Lessons Learned

- Single-replica Longhorn volumes are vulnerable to single-node failures
- 1Gi for logs is insufficient; cascading ENOSPC failures compound the primary issue
- When Longhorn auto-salvage gets stuck (`salvageExecuted: true` with 0 eligible replicas), manually resetting the replica's `failedAt` and `salvageRequested` fields via kubectl patch is the effective fix
- DiskPressure on a node can block salvage operations; reducing `storageReserved` can unblock scheduling
