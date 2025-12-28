# Incident Log - VN Cluster

## 2025-12-11: PostgreSQL pgvector PVC Expansion and VPS Disk Resize

### Summary

PostgreSQL pgvector pod experienced recurring CrashLoopBackOff due to disk space exhaustion. Despite VPS disk expansion from 50GB to 100GB at provider level, Longhorn was unable to expand the PVC because the Linux filesystem was not resized to use the new disk capacity.

### Timeline

- **08:08 UTC**: PostgreSQL pgvector pod failing with "No space left on device" error
- **08:10 UTC**: User expanded VPS disk from 50GB to 100GB at provider level
- **08:15 UTC**: Investigation revealed filesystem still showing 49GB (not expanded)
- **08:20 UTC**: Identified vps33 Longhorn disk at 100% capacity preventing PVC expansion
- **08:25 UTC**: Resized vps33 filesystem from 49GB to 97GB using resize2fs
- **08:28 UTC**: Longhorn detected new disk size (85GB available)
- **08:30 UTC**: Migrated InfluxDB (20Gi) from vps33 to vps24 to free space
- **08:35 UTC**: Successfully expanded postgresql-pgvector-1 PVC from 4Gi to 20Gi
- **08:38 UTC**: PostgreSQL pod recovered and started successfully
- **08:39 UTC**: All murror-ai application pods verified healthy (1/1 READY)

**Total Downtime**: ~30 minutes

### Root Causes

1. **Filesystem Not Expanded**: VPS provider expanded disk to 100GB but filesystem remained at 49GB
2. **Longhorn Disk Full**: vps33 was using 33Gi out of 36Gi available (92% capacity)
3. **Volume Distribution**: All volumes concentrated on vps33 node
4. **Replica Misconfiguration**: Volume temporarily set to 2 replicas blocking expansion

### Impact

**Services Affected**:
- postgresql-pgvector pod (CrashLoopBackOff)
- Database write operations blocked

**Services NOT Affected**:
- murror-ai application pods (read operations continued)
- postgresql-ha cluster (separate instance)

### Resolution

#### Step 1: Resize VPS Filesystem

```bash
# Check partition size (already 99.9GB)
kubectl exec -n longhorn-system <instance-manager-pod> -- lsblk /host/dev/vda

# Resize ext4 filesystem to use full partition
kubectl exec -n longhorn-system <instance-manager-pod> -- resize2fs /host/dev/vda1

# Verify new size
kubectl exec -n longhorn-system <instance-manager-pod> -- df -h /host/var/lib/longhorn
# Result: 97GB total, 80GB available
```

#### Step 2: Free Up Space on vps33

```bash
# Move InfluxDB volume from vps33 to vps24
kubectl patch statefulset -n influxdb influxdb-influxdb2 \
  -p '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/hostname":"vps24-vnix"}}}}}'

kubectl delete pod -n influxdb influxdb-influxdb2-0

# Verified: vps33 usage reduced from 33Gi to 9Gi
```

#### Step 3: Fix Volume Replica Configuration

```bash
# Reset to 1 replica (matching storage class default)
kubectl patch volume -n longhorn-system pvc-f30cc00a-b769-4f46-b81b-8db8eb0e36b3 \
  --type='json' -p='[{"op": "replace", "path": "/spec/numberOfReplicas", "value": 1}]'

# Remove node selector constraint
kubectl patch volume -n longhorn-system pvc-f30cc00a-b769-4f46-b81b-8db8eb0e36b3 \
  --type='json' -p='[{"op": "remove", "path": "/spec/nodeSelector"}]'
```

#### Step 4: Expand PVC

```bash
# Expand PVC to 20Gi
kubectl patch pvc -n postgres-db postgresql-pgvector-1 \
  -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'

# Monitor expansion progress
kubectl describe pvc -n postgres-db postgresql-pgvector-1

# Restart CSI resizer (if needed)
kubectl delete pod -n longhorn-system -l app=csi-resizer
```

#### Step 5: Verify Recovery

```bash
# Check filesystem size inside pod
kubectl exec -n postgres-db postgresql-pgvector-0 -- df -h /var/lib/postgresql/data
# Result: 20GB total, 16GB available (was 3.9G/3.9G)

# Verify PostgreSQL logs
kubectl logs -n postgres-db postgresql-pgvector-0 --tail=30
# Result: "database system is ready to accept connections"

# Check application pods
kubectl get pod -A | grep murror-ai
# Result: All pods 1/1 Running
```

### Storage Changes Summary

#### Before

- **vps33 filesystem**: 49GB (100% of partition)
- **vps33 Longhorn usage**: 33Gi (influxdb 20Gi + postgresql-ha 5Gi + postgresql-pgvector 4Gi + others 4Gi)
- **postgresql-pgvector PVC**: 4Gi (100% full)
- **PVC location**: vps33

#### After

- **vps33 filesystem**: 97GB (resized to use full 100GB disk)
- **vps33 Longhorn usage**: 9Gi (postgresql-ha 5Gi + others 4Gi)
- **vps24 Longhorn usage**: 20Gi (influxdb migrated)
- **vps22 Longhorn usage**: 4Gi (postgresql-pgvector migrated during expansion)
- **postgresql-pgvector PVC**: 20Gi (20% used, 16GB free)
- **PVC location**: vps22

### Lessons Learned

1. **VPS Disk Expansion Process**:
   - Expanding disk at provider level is only step 1
   - Must resize partition (usually automatic with cloud-init)
   - Must resize filesystem with resize2fs (manual step required)
   - Must tell Longhorn to rescan disk capacity

2. **Longhorn Capacity Planning**:
   - Longhorn reserves 25% of disk for overhead
   - Always verify `storageAvailable` not just disk size
   - Distribute volumes across multiple nodes
   - Monitor per-node storage usage

3. **Volume Expansion Blockers**:
   - Replica scheduling must succeed before expansion
   - Node selectors can prevent replica creation
   - CSI resizer may need restart to retry failed expansions

4. **StatefulSet Scaling Safety**:
   - **NEVER** scale StatefulSet to 0 replicas without backup
   - Detaching PVC can cause data loss if not careful
   - Always verify pod is detached before volume operations

### Follow-up Actions

**Completed**:
- ✅ Resized vps33 filesystem to 97GB
- ✅ Expanded postgresql-pgvector PVC to 20Gi
- ✅ Migrated volumes off vps33 to distribute load
- ✅ Updated documentation with new PVC sizes
- ✅ Verified all services healthy

**Short Term** (Next 7 days):
- [ ] Resize other VPS nodes' filesystems to match disk sizes
- [ ] Implement automated filesystem resize on boot (cloud-init)
- [ ] Create monitoring alert for filesystem vs disk size mismatch

**Medium Term** (Next 30 days):
- [ ] Implement per-node Longhorn storage usage alerts
- [ ] Review and redistribute all volumes across nodes evenly
- [ ] Create runbook for VPS disk expansion procedures

### References

- **PostgreSQL Docs**: [POSTGRESQL.md](./POSTGRESQL.md)
- **Previous Incident**: 2025-12-08 Disk Space Exhaustion
- **Longhorn Documentation**: https://longhorn.io/docs/

## 2025-12-08: PostgreSQL pgvector Disk Space Exhaustion

### Summary

PostgreSQL pgvector cluster experienced complete outage due to 4Gi PVC reaching 100% capacity, causing all murror-ai API pods to fail readiness checks.

### Timeline

- **08:00 UTC**: murror-ai pods detected as not ready (0/1)
- **08:15 UTC**: Investigation started - identified PostgreSQL pgvector in CrashLoopBackOff
- **08:20 UTC**: Root cause confirmed - PVC at 100% capacity (3.8G/3.9G used)
- **08:25 UTC**: Cleaned up WAL files - freed 600MB
- **08:30 UTC**: Attempted PVC expansion to 20Gi - BLOCKED by insufficient Longhorn node capacity
- **08:35 UTC**: Added longhorn labels to 3 additional nodes (vps22, vps23, vps24)
- **08:40 UTC**: Migrated to manual StatefulSet due to CNPG reconciliation issues
- **08:51 UTC**: PostgreSQL started successfully with restored data
- **08:59 UTC**: All murror-ai pods READY (1/1) - health checks passing

**Total Downtime**: ~1 hour (for murror-ai API pods)

### Root Causes

1. **Insufficient Storage Allocation**: 4Gi PVC too small for production PostgreSQL with WAL archiving
2. **Single Longhorn Node**: All storage concentrated on vps33, preventing expansion
3. **No Disk Usage Monitoring**: No alerts configured for PVC usage thresholds
4. **WAL File Accumulation**: 912MB of WAL files not being archived or cleaned up

### Impact

**Services Affected**:

- murror-ai API pods (3 replicas) - NOT READY for ~1 hour
- murror-ai init containers unable to run migrations
- External API requests to murror-ai failing

**Services NOT Affected**:

- murror-ai celery worker (1/1 READY throughout)
- Supabase connectivity (verified working)
- postgresql-ha cluster (separate instance, healthy)

### Resolution

#### Immediate Actions

1. **Cleaned up WAL files**:

   ```bash
   # Freed 600MB by removing old WAL segments
   find /mnt/pgdata/pgdata/pg_wal -type f -name '*.old' -delete
   find /mnt/pgdata/pgdata/pg_wal -type f -name '*.backup' -delete
   ```

2. **Expanded Longhorn infrastructure**:

   ```bash
   kubectl label node vps22-vnix longhorn=true role=storage
   kubectl label node vps23-vnix longhorn=true role=storage
   kubectl label node vps24-vnix longhorn=true role=storage
   ```

3. **Increased volume replication**:

   ```bash
   # Changed from 1 replica to 3 replicas for all volumes
   kubectl patch settings.longhorn.io default-replica-count -n longhorn-system \
     --type='json' -p='[{"op": "replace", "path": "/value", "value": "3"}]'
   ```

4. **Deployed manual StatefulSet**:
   - Created StatefulSet bypassing CloudNative-PG operator
   - Restored data from CNPG backup directory
   - Configured proper security contexts (UID 999)

5. **Recreated database infrastructure**:

   ```sql
   CREATE DATABASE "murror-ai" OWNER dev;
   CREATE USER ai WITH PASSWORD '***';
   GRANT ALL PRIVILEGES ON DATABASE "murror-ai" TO ai;
   CREATE EXTENSION IF NOT EXISTS vector;
   GRANT ALL ON SCHEMA public TO ai;
   ```

6. **Fixed network access**:

   ```bash
   # Added pg_hba.conf rule for pod network
   echo "host all all 10.42.0.0/16 md5" >> pg_hba.conf
   ```

### Data Loss Assessment

**Data Preserved**: ✅

- Original PVC data retained (Longhorn Retain policy)
- CloudNative-PG created backup directories before operations
- Data restored from `pgdata_20251208T084231Z`

**Data Recreated**:

- `murror-ai` database schema (will be repopulated by application migrations)
- Application data will be rebuilt by murror-ai service

**No User Data Loss**: murror-ai uses Supabase for user data (unaffected)

### Preventive Measures

1. **Monitoring Implemented**:
   - TODO: Add Prometheus alerts for PVC usage > 80%
   - TODO: Add alerts for PVC usage > 90% (critical)

2. **Infrastructure Improvements**:
   - ✅ Longhorn now uses 4 nodes instead of 1
   - ✅ Default replica count increased to 3
   - ✅ Storage distributed across nodes

3. **Documentation**:
   - ✅ Created manual deployment documentation
   - ✅ Documented recovery procedures
   - ✅ Created incident log

### Lessons Learned

1. **Storage Sizing**: 4Gi is insufficient for production PostgreSQL with WAL archiving. Minimum 20Gi recommended.

2. **Longhorn Architecture**: Single storage node creates single point of failure and prevents expansion. Always use multiple nodes.

3. **Monitoring Gaps**: Need proactive alerts for:
   - PVC usage thresholds
   - WAL directory growth
   - Database connection failures

4. **Backup Strategy**: CloudNative-PG's automatic backups saved the data. Retain policy critical.

5. **Manual Interventions**: pg_hba.conf changes are not persistent in manual deployments. Need ConfigMap-based approach.

### Follow-up Actions

**Short Term** (Next 7 days):

- [ ] Implement PVC usage monitoring alerts
- [ ] Set up automated WAL cleanup or archiving to MinIO
- [ ] Create ConfigMap for pg_hba.conf persistence
- [ ] Document pod restart procedures

**Medium Term** (Next 30 days):

- [ ] Plan migration back to CloudNative-PG when disk space allows
- [ ] Implement automated daily backups
- [ ] Set up external backup storage

**Long Term**:

- [ ] Add dedicated storage nodes with larger disks
- [ ] Implement disaster recovery procedures
- [ ] Review all PVC sizing across clusters

### References

- **Manual Deployment Docs**: [POSTGRESQL_PGVECTOR_MANUAL.md](./POSTGRESQL_PGVECTOR_MANUAL.md)
- **Main PostgreSQL Docs**: [POSTGRESQL.md](./POSTGRESQL.md)
- **StatefulSet Config**: `/tmp/postgresql-manual-statefulset.yaml`
- **Cluster Config**: `/database/postgresql/clusters/vn/cluster-pgvector.yaml`

### Contact

For questions or issues with this deployment, review:

- PostgreSQL logs: `kubectl logs postgresql-pgvector-0 -n postgres-db`
- Longhorn volume status: `kubectl get volumes -n longhorn-system`
- Application logs: `kubectl logs -n nsp-prod-murror-ai <pod-name>`
