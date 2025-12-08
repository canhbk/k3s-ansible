# Incident Log - VN Cluster

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
