# Fixing barman-cloud WAL Archiving for VN PostgreSQL Cluster

## Problem
After installing the barman-cloud plugin v0.6.0 for CloudNativePG v1.26.0, the PostgreSQL cluster `postgresql-pgvector` in the VN cluster was failing to archive WAL files with the error:
```
exec: "barman-cloud-wal-archive": executable file not found in $PATH
```

## Root Cause
The PostgreSQL cluster was using the `pgvector/pgvector:0.8.0-pg17` image, which doesn't include the barman-cloud binaries. The barman-cloud plugin for CloudNativePG doesn't inject binaries into PostgreSQL pods; it acts as a separate service.

## Solution

### 1. Switch to CloudNativePG PostgreSQL Image
Changed the PostgreSQL image from `pgvector/pgvector:0.8.0-pg17` to `ghcr.io/cloudnative-pg/postgresql:17.2`, which includes barman-cloud binaries.

**Updated ClusterImageCatalog:**
```yaml
apiVersion: postgresql.cnpg.io/v1
kind: ClusterImageCatalog
metadata:
  name: postgresql-pgvector-cnpg
  namespace: postgres-db
spec:
  images:
    - major: 17
      image: ghcr.io/cloudnative-pg/postgresql:17.2
```

### 2. Fix MinIO Bucket Permissions
The initial configuration used a non-existent bucket `postgresql-pgvector-wal`. Changed to use the existing bucket `postgres-wal` with proper path:
```yaml
backup:
  barmanObjectStore:
    destinationPath: "s3://postgres-wal/pgvector-vn"
```

### 3. Apply Configuration
```bash
# Apply updated configuration
kubectl apply -f cluster-pgvector-with-barman.yaml

# Force pod recreation to use new image
kubectl delete pod postgresql-pgvector-1 -n postgres-db
```

## Verification

### Check Cluster Status
```bash
kubectl get clusters.postgresql.cnpg.io postgresql-pgvector -n postgres-db -o jsonpath='{.status.conditions}' | jq .
```

Expected output should show:
```json
{
  "message": "Continuous archiving is working",
  "reason": "ContinuousArchivingSuccess",
  "status": "True",
  "type": "ContinuousArchiving"
}
```

### Verify WAL Files in MinIO
Use the verification script:
```bash
./database/postgresql/scripts/verify-wal-archiving.sh
```

This will list all archived WAL files in MinIO storage.

## Important Notes

1. **Image Compatibility**: When using pgvector extension, ensure the CloudNativePG PostgreSQL image supports it or install it via `postInitSQL`.

2. **UID/GID**: The CloudNativePG PostgreSQL image uses UID/GID 26 by default, but we kept 999 for compatibility with existing data.

3. **Plugin vs Built-in**: CloudNativePG v1.26.0 shows a deprecation warning about native barman support. The barman-cloud plugin will be required in future versions.

## Files Created/Modified

1. `/database/postgresql/clusters/vn/cluster-pgvector-with-barman.yaml` - Updated cluster configuration
2. `/database/postgresql/scripts/create-minio-bucket.sh` - Script to test MinIO connectivity
3. `/database/postgresql/scripts/verify-wal-archiving.sh` - Script to verify WAL archiving

## Timeline

- **2025-08-27 10:45**: Issue identified - barman-cloud-wal-archive not found
- **2025-08-27 11:56**: Switched to CloudNativePG PostgreSQL image
- **2025-08-27 12:05**: Fixed MinIO bucket configuration
- **2025-08-27 12:08**: Verified WAL archiving is working

## Conclusion

The issue has been successfully resolved. WAL archiving is now functioning properly with:
- WAL files being compressed and archived to MinIO
- Proper backup files being created
- Continuous archiving status showing as successful