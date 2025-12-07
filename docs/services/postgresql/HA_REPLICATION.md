# PostgreSQL High Availability Cross-Cluster Replication

## Overview

This document outlines the PostgreSQL High Availability (HA) cross-cluster replication architecture between the VN (Vietnam) and US clusters. The setup provides:

- Continuous data synchronization between primary (VN) and replica (US) clusters
- Disaster recovery capabilities
- Low-latency standby database for potential failover

## Current Status

- **VN Primary**: PostgreSQL HA with WAL archiving to MinIO (US cluster)
- **US Replica**: Streaming replication from VN
- **Replication Method**: Streaming-only using pg_basebackup bootstrap
- **WAL Recovery**: Not configured (would require base backups in MinIO)

## Architecture Diagram

```
+-------------------+    WAL Archiving    +----------------------+
|   VN Cluster      | -----------------> |    US Cluster         |
| [Primary Cluster] |   (MinIO Storage)   | [Replica/Standby]     |
|                   |                     |                      |
| postgresql-ha     | <----------------- | postgresql-ha-replica|
| (Primary Instance)|    Streaming        | (Replica Instance)   |
+-------------------+    Replication      +----------------------+
        |                                         |
        v                                         v
   [WAL Archiving]                        [Streaming Replica]
   MinIO S3 Storage                       Continuously Synced
```

## Configuration Details

### VN Cluster (Primary)
- **Cluster Name**: `postgresql-ha`
- **Namespace**: `postgres-db`
- **Replication User**: `replication_user_ha`
- **WAL Archiving**: Configured to MinIO at `s3://postgres-wal/postgresql-ha-vn`
- **External Access**: LoadBalancer on port 5434 for replication
- **Node Access**: NodePort on 30432 for direct access

### US Cluster (Replica)
- **Cluster Name**: `postgresql-ha-replica`
- **Namespace**: `postgres-db`
- **Replication Method**: Streaming replication from VN cluster
- **Bootstrap Method**: pg_basebackup from VN primary
- **MinIO Access**: Internal endpoint at `minio-internal.minio.svc.cluster.local:9000`

## Implementation Steps

1. **Prepare VN Cluster**
   - Configure CloudNativePG operator
   - Set up MinIO for WAL archiving
   - Create replication user
   - Configure cluster with WAL archiving enabled

2. **Configure US Cluster Replica**
   - Deploy CloudNativePG operator
   - Create replica cluster configuration
   - Point to VN cluster's MinIO WAL archive
   - Set up streaming replication

3. **Set Up Secrets and Access**
   - Create Kubernetes secrets for replication credentials
   - Configure network policies
   - Set up external LoadBalancer service for replica cluster

## Verification Commands

```bash
# VN Cluster (Primary) Verification
kubectl get clusters -n postgres-db postgresql-ha
kubectl get pods -n postgres-db -l cnpg.io/cluster=postgresql-ha

# US Cluster (Replica) Verification
kubectl get clusters -n postgres-db postgresql-ha-replica
kubectl get pods -n postgres-db -l cnpg.io/cluster=postgresql-ha-replica

# Check Replication Status
kubectl exec -n postgres-db postgresql-ha-1 -- \
  psql -c "SELECT * FROM pg_stat_replication;"

# Verify WAL Archiving
kubectl exec -n postgres-db postgresql-ha-1 -- \
  psql -c "SELECT * FROM pg_stat_archiver;"
```

## Troubleshooting

### Common Issues

1. **Replication Lag**
   - Check `pg_stat_replication` for current lag
   - Verify network connectivity between clusters
   - Ensure sufficient resources on both clusters

2. **WAL Archiving Failures**
   - Verify MinIO bucket permissions
   - Check network connectivity to MinIO
   - Validate S3 storage credentials

3. **Streaming Replication Interruption**
   - Restart replication pods
   - Verify network policies
   - Check cluster network configurations

### Diagnostic Commands

```bash
# Check Replication Lag
kubectl exec postgresql-ha-1 -- \
  psql -c "SELECT * FROM pg_stat_replication;"

# View WAL Archiving Logs
kubectl logs -n postgres-db postgresql-ha-1 \
  -c postgres | grep -i archive

# Verify MinIO Connectivity
kubectl exec -n postgres-db postgresql-ha-1 -- \
  psql -c "SELECT * FROM pg_available_extensions WHERE name = 's3';"
```

## Security Considerations

1. **Encryption**
   - Use SSL/TLS for all connections
   - Encrypt WAL archives in MinIO
   - Rotate credentials regularly

2. **Network Security**
   - Implement strict network policies
   - Use Wireguard or similar VPN for inter-cluster communication
   - Restrict external access to necessary IPs

3. **Secret Management**
   - Use Kubernetes Secrets or external secret management
   - Rotate replication user credentials periodically
   - Avoid hardcoding credentials in manifests

4. **Monitoring**
   - Set up Prometheus/Grafana for replication health
   - Configure alerting for replication lag
   - Monitor authentication attempts

## Recommended Maintenance

- Monthly credential rotation
- Quarterly disaster recovery drills
- Regular RPO/RTO testing
- Keep CloudNativePG operator updated

## Last Updated
- Date: 2025-08-28
- Version: 1.0
- Replication Method: Streaming with WAL Archiving