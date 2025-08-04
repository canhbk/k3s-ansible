# PostgreSQL High Availability

This directory contains the PostgreSQL HA deployment configurations using CloudNative-PG operator for all K3s clusters.

## Overview

CloudNative-PG is a Kubernetes operator that covers the full lifecycle of a highly available PostgreSQL database cluster with a primary/standby architecture, using native streaming replication.

## Directory Structure

```
postgresql/
├── README.md                 # This file
├── base/                     # Base configurations
│   ├── namespace.yaml       # PostgreSQL namespace
│   ├── cnpg-operator/       # CloudNative-PG operator installation
│   └── secrets/             # Secret templates and documentation
├── clusters/                 # Cluster-specific configurations
│   ├── dev/                 # Development cluster
│   ├── vn/                  # Vietnam production cluster
│   ├── production/          # Production templates
│   └── ...                  # Other clusters (eu, jp, sg, sg2, us, vn2)
└── scripts/                  # Deployment and management scripts
    ├── deploy.sh            # Automated deployment script
    └── backup.sh            # Backup management script
```

## Quick Start

### 1. Install CloudNative-PG Operator

```bash
# Using the deployment script
./scripts/deploy.sh dev

# Or manually
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.26/releases/cnpg-1.26.0.yaml
```

### 2. Deploy PostgreSQL Cluster

```bash
# Deploy to dev cluster
./scripts/deploy.sh dev

# Deploy to production cluster
./scripts/deploy.sh vn

# Deploy with custom namespace
./scripts/deploy.sh -n custom-namespace eu
```

### 3. Verify Deployment

```bash
# Check cluster status
kubectl get cluster -n postgres-db

# Check pods
kubectl get pods -n postgres-db

# Check services
kubectl get svc -n postgres-db
```

## Features

### Development Clusters
- Single instance deployment
- pgvector extension support (AI/ML workloads)
- External LoadBalancer access (dev only)
- Local storage

### Production Clusters
- High availability with 3+ instances
- Pod anti-affinity for fault tolerance
- Resource limits and requests
- Monitoring enabled
- Backup configuration support
- Optimized PostgreSQL parameters

## Cluster Configurations

| Cluster | Environment | Storage Class | Instance Count | Special Features |
|---------|-------------|---------------|----------------|------------------|
| dev     | Development | local-path    | 1              | pgvector, LoadBalancer |
| vn      | Production  | longhorn-vn   | 1 (scalable)   | Production settings |
| eu      | Production  | TBD           | 3              | HA configuration |
| jp      | Production  | TBD           | 3              | HA configuration |
| sg      | Production  | TBD           | 3              | HA configuration |
| sg2     | Production  | TBD           | 3              | HA configuration |
| us      | Production  | TBD           | 3              | HA configuration |
| vn2     | Production  | TBD           | 3              | HA configuration |

## Management Scripts

### deploy.sh
Automated deployment script for PostgreSQL clusters.

```bash
# Show help
./scripts/deploy.sh -h

# Deploy with status display
./scripts/deploy.sh -s dev

# Deploy specific operator version
./scripts/deploy.sh -v 1.25.0 vn
```

### backup.sh
Comprehensive backup management for PostgreSQL clusters.

```bash
# Create on-demand backup
./scripts/backup.sh create

# List all backups
./scripts/backup.sh list

# Show backup details
./scripts/backup.sh show backup-20240115-120000

# Restore from backup
./scripts/backup.sh restore backup-20240115-120000

# Export database to SQL
./scripts/backup.sh -d mydb export
```

## Security

### Secrets Management

1. **Never commit real passwords** - Use templates in `base/secrets/`
2. **Generate strong passwords**:
   ```bash
   openssl rand -base64 32
   ```
3. **Use separate passwords** for each environment and user
4. **Enable encryption at rest** for etcd
5. **Configure RBAC** appropriately

### Network Security

- Use NetworkPolicies to restrict access
- Enable SSL/TLS for connections
- Configure firewall rules for LoadBalancer services
- Implement IP whitelisting where possible

## Monitoring

CloudNative-PG provides Prometheus metrics out of the box:

```yaml
monitoring:
  enabled: true
```

Key metrics to monitor:
- PostgreSQL connections
- Replication lag
- Disk usage
- Query performance
- Backup status

## Backup Strategies

### On-Demand Backups
```bash
./scripts/backup.sh create
```

### Scheduled Backups
Configure in cluster spec:
```yaml
backup:
  retentionPolicy: "30d"
  schedule: "0 2 * * *"  # Daily at 2 AM
  target: "s3://your-bucket/backups"
```

### Backup Storage Options
- S3/S3-compatible storage
- Azure Blob Storage
- Google Cloud Storage
- Local persistent volumes

## Troubleshooting

### Common Issues

1. **Cluster not becoming ready**
   ```bash
   kubectl describe cluster postgresql-ha -n postgres-db
   kubectl logs -n postgres-db -l cnpg.io/cluster=postgresql-ha
   ```

2. **Connection issues**
   ```bash
   kubectl exec -it -n postgres-db postgresql-ha-1 -- psql -U postgres
   ```

3. **Storage issues**
   ```bash
   kubectl get pvc -n postgres-db
   kubectl describe pvc -n postgres-db
   ```

### Useful Commands

```bash
# Get cluster status
kubectl get cluster -n postgres-db

# Watch pods
kubectl get pods -n postgres-db -w

# Check operator logs
kubectl logs -n cnpg-system deployment/cnpg-controller-manager

# Access PostgreSQL
kubectl exec -it -n postgres-db postgresql-ha-1 -- psql -U postgres
```

## References

- [CloudNative-PG Documentation](https://cloudnative-pg.io/)
- [CloudNative-PG GitHub](https://github.com/cloudnative-pg/cloudnative-pg)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [pgvector Extension](https://github.com/pgvector/pgvector)