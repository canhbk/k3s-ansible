# Phase 2 Implementation Plan - VN Primary Cluster WAL Archiving

**Status**: READY FOR IMPLEMENTATION
**Date**: 2025-08-27
**Risk Level**: HIGH - Modifies production primary database

## Prerequisites Completed (Phase 1)

- ✅ MinIO deployed in US cluster (<http://64.71.161.44:9000>)
- ✅ Bucket created: postgres-wal
- ✅ User created: postgres-user
- ✅ User has read/write permissions on postgres-wal bucket

## Summary of Changes

### 1. PostgreSQL Configuration Changes

- Add replication parameters (max_wal_senders, wal_keep_size, etc.)
- Enable WAL archiving to MinIO
- Add performance tuning parameters

### 2. New Resources to Create

- MinIO credentials secret
- Streaming replica user secret
- External LoadBalancer service for replication (14.225.210.189:5432)

### 3. Database Modifications

- Add streaming_replica user with replication privileges
- Enable pgvector extension via postInitSQL
- Configure barmanObjectStore for WAL archiving

## Risk Assessment

### Risks

1. **Service Disruption**: The cluster update will trigger a rolling restart
   - **Mitigation**: CloudNativePG performs controlled rolling updates
   - **Expected Downtime**: ~2-5 minutes for single instance

2. **WAL Archive Failure**: If MinIO is unreachable, WAL archiving might fail
   - **Mitigation**: PostgreSQL will continue running, only archiving is affected
   - **Recovery**: Fix connectivity, WALs will be archived when connection restored

3. **Configuration Errors**: Invalid parameters could prevent PostgreSQL from starting
   - **Mitigation**: Configuration has been validated against CloudNativePG docs
   - **Recovery**: Revert to backup configuration

### Low Risk Aspects

- Adding new users doesn't affect existing connections
- LoadBalancer service creation is non-disruptive
- WAL archiving is asynchronous and won't block transactions

## Step-by-Step Implementation

### Pre-Implementation Checks

```bash
# 1. Verify current cluster health
kubectl get clusters.postgresql.cnpg.io postgresql-pgvector -n postgres-db

# 2. Check current connections
kubectl exec -it postgresql-pgvector-1 -n postgres-db -- psql -U postgres -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';"

# 3. Create fresh backup
kubectl exec -it postgresql-pgvector-1 -n postgres-db -- pg_dump -U postgres --format=custom -f /tmp/backup-$(date +%Y%m%d-%H%M%S).dump

# 4. Test MinIO connectivity from VN cluster
curl -I http://64.71.161.44:9000
```

### Implementation Steps

#### Step 1: Apply Secrets (Non-disruptive)

```bash
# Apply MinIO credentials
kubectl apply -f database/postgresql/clusters/vn/secrets-minio.yaml

# Apply streaming replica secret
kubectl apply -f database/postgresql/clusters/vn/streaming-replica-pgvector-secret.yaml

# Verify secrets
kubectl get secrets -n postgres-db | grep -E "(minio|streaming)"
```

#### Step 2: Update Cluster Configuration (DISRUPTIVE - Rolling restart)

```bash
# Apply the updated cluster configuration
kubectl apply -f database/postgresql/clusters/vn/cluster-pgvector-updated.yaml

# Monitor the rolling update
kubectl get pods -n postgres-db -w

# Check cluster status
kubectl get clusters.postgresql.cnpg.io postgresql-pgvector -n postgres-db
```

#### Step 3: Verify WAL Archiving

```bash
# Check PostgreSQL logs for archive success
kubectl logs postgresql-pgvector-1 -n postgres-db | grep -i "archive"

# Force a WAL switch to test archiving
kubectl exec -it postgresql-pgvector-1 -n postgres-db -- psql -U postgres -c "SELECT pg_switch_wal();"

# Check MinIO for WAL files (from US cluster)
kubectl config use-context us
kubectl exec -it minio-<pod-id> -n minio -- mc ls myminio/postgres-wal/postgresql-pgvector-wal/vn/
kubectl config use-context vn
```

#### Step 4: Verify External Access

```bash
# Check LoadBalancer service
kubectl get svc postgresql-pgvector-replication -n postgres-db

# Test replication connectivity (from external host)
psql -h 14.225.210.189 -p 5432 -U streaming_replica -d postgres -c "IDENTIFY_SYSTEM;" replication=1
```

### Post-Implementation Verification

1. **Cluster Health**:

   ```bash
   kubectl describe clusters.postgresql.cnpg.io postgresql-pgvector -n postgres-db
   ```

2. **Replication User**:

   ```bash
   kubectl exec -it postgresql-pgvector-1 -n postgres-db -- psql -U postgres -c "SELECT * FROM pg_user WHERE usename = 'streaming_replica';"
   ```

3. **WAL Archiving Status**:

   ```bash
   kubectl exec -it postgresql-pgvector-1 -n postgres-db -- psql -U postgres -c "SELECT * FROM pg_stat_archiver;"
   ```

4. **Application Connectivity**:

   ```bash
   # Test each application database
   kubectl exec -it postgresql-pgvector-1 -n postgres-db -- psql -U ai -d murror-ai -c "SELECT 1;"
   kubectl exec -it postgresql-pgvector-1 -n postgres-db -- psql -U be -d murror-be -c "SELECT 1;"
   ```

### Rollback Plan

If issues occur:

1. **Immediate Rollback**:

   ```bash
   # Apply the backup configuration
   kubectl apply -f database/postgresql/clusters/vn/cluster-pgvector.yaml

   # Monitor rollback
   kubectl get pods -n postgres-db -w
   ```

2. **Remove New Resources**:

   ```bash
   kubectl delete svc postgresql-pgvector-replication -n postgres-db
   kubectl delete secret postgresql-minio-credentials -n postgres-db
   kubectl delete secret streaming-replica-pgvector-secret -n postgres-db
   ```

## Success Criteria

- [ ] Cluster remains healthy after update
- [ ] All existing databases and users are functional
- [ ] WAL files appear in MinIO bucket
- [ ] External replication service is accessible
- [ ] No errors in PostgreSQL logs
- [ ] Applications can connect and query normally

## Next Steps (Phase 3)

Once Phase 2 is verified stable (recommend 24 hours):

- Deploy standby cluster in US region
- Configure streaming replication from VN to US
- Test failover procedures

## Important Notes

- Monitor the cluster closely for 1 hour after implementation
- Keep the backup configuration readily available
- Document any issues or deviations from the plan
- Update monitoring alerts for WAL archiving status
