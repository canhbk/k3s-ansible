# PostgreSQL Distributed Setup - Quick Reference

## Current State (2025-08-27)

### VN Primary

- **Cluster**: postgresql-pgvector
- **Namespace**: postgres-db
- **External IP**: 14.225.210.108:5433
- **Status**: ✅ Primary, WAL archiving active

### US Replica

- **Cluster**: postgresql-pgvector-replica
- **Namespace**: postgres-db
- **Status**: ✅ Standby mode, streaming replication active
- **Lag**: < 1 second

### MinIO (US)

- **External IP**: 64.71.161.44:9000
- **Bucket**: postgres-wal
- **Status**: ✅ Receiving WAL archives

## Essential Commands

### Check Replication Status

```bash
# VN Primary - show connected replicas
kubectl config use-context vn
kubectl exec -it postgresql-pgvector-1 -n postgres-db -- psql -U postgres \
  -c "SELECT client_addr, state, sync_state FROM pg_stat_replication;"

# US Replica - verify standby mode
kubectl config use-context us
kubectl exec -it postgresql-pgvector-replica-1 -n postgres-db -- psql -U postgres \
  -c "SELECT pg_is_in_recovery();"  # Should return 't'
```

### Monitor Health

```bash
# WAL archiving status
kubectl get clusters.postgresql.cnpg.io postgresql-pgvector -n postgres-db \
  -o jsonpath='{.status.conditions[?(@.type=="ContinuousArchiving")]}'

# Replication lag
kubectl exec -it postgresql-pgvector-replica-1 -n postgres-db -- psql -U postgres \
  -c "SELECT now() - pg_last_xact_replay_timestamp() AS lag;"
```

### Troubleshooting

```bash
# View recent WAL archive logs
kubectl logs postgresql-pgvector-1 -n postgres-db | grep -i "archive" | tail -20

# Check cluster conditions
kubectl describe clusters.postgresql.cnpg.io postgresql-pgvector -n postgres-db
```

## Key Configuration Files

- **VN Primary**: `clusters/vn/cluster-pgvector-with-barman.yaml`
- **US Replica**: `clusters/us/cluster-pgvector-replica-streaming.yaml`
- **MinIO Creds**: `clusters/vn/secrets-minio.yaml`

## Important Notes

1. **Image Required**: `ghcr.io/cloudnative-pg/postgresql:17.2` (includes pgvector + barman-cloud)
2. **Replica Config**: Must have `replica.enabled: true`
3. **Failover**: `kubectl cnpg promote postgresql-pgvector-replica -n postgres-db`

## Credentials Location

- **Superuser**: `kubectl get secret superuser-pgvector-secret -n postgres-db`
- **Replication**: `kubectl get secret streaming-replica-pgvector-secret -n postgres-db`
- **MinIO**: `kubectl get secret postgresql-minio-credentials -n postgres-db`
