# VPS Management Database Connection Information - VN Production

## Database Details
- **Database Name**: `vps-management`
- **Username**: `vps`
- **Password**: `<REPLACE_WITH_ACTUAL_PASSWORD>`
- **Owner**: vps user
- **Cluster**: postgresql-pgvector (with pgvector extension)
- **Namespace**: postgres-db
- **Environment**: PRODUCTION (VN cluster)

## Connection Endpoints

### Internal Access (within cluster)
- **Read/Write**: `postgresql-pgvector-rw.postgres-db.svc.cluster.local:5432`
- **Read-only**: `postgresql-pgvector-ro.postgres-db.svc.cluster.local:5432`
- **Any instance**: `postgresql-pgvector-r.postgres-db.svc.cluster.local:5432`

### External Access (LoadBalancer)
- **Service Name**: `postgres-vps-management-pgvector`
- **Port**: 5432
- **External IPs**: Will be assigned from pool: 14.225.210.108, 14.225.210.165, 14.225.210.170
- **NodePort**: 32363

## Connection String Examples

### Internal (from within the cluster)
```
postgresql://vps:<REPLACE_WITH_ACTUAL_PASSWORD>@postgresql-pgvector-rw.postgres-db.svc.cluster.local:5432/vps-management
```

### External (once LoadBalancer IPs are assigned)
```
postgresql://vps:<REPLACE_WITH_ACTUAL_PASSWORD>@<EXTERNAL-IP>:5432/vps-management
```

## Features
- PostgreSQL 17 with pgvector 0.8.0 extension
- Storage: 4Gi on Longhorn storage class
- Node affinity: Requires nodes with `longhorn=true` label

## Verification Commands

```bash
# Check database status
kubectl get databases.postgresql.cnpg.io -n postgres-db | grep vps

# Check LoadBalancer service
kubectl get svc postgres-vps-management-pgvector -n postgres-db

# Check cluster status
kubectl describe clusters.postgresql.cnpg.io postgresql-pgvector -n postgres-db

# Connect to database from within cluster
kubectl run -it --rm --image=postgres:17 psql-test -- psql "postgresql://vps:<REPLACE_WITH_ACTUAL_PASSWORD>@postgresql-pgvector-rw.postgres-db.svc.cluster.local:5432/vps-management"
```

## Security Notes
- This is a PRODUCTION environment - strong passwords are mandatory
- External access is exposed via LoadBalancer
- Consider implementing:
  - Firewall rules to restrict access
  - VPN connection for secure access
  - Regular password rotation
  - Connection encryption (SSL/TLS)

## pgvector Extension
The pgvector extension is available for storing and querying vector embeddings, useful for:
- Similarity search
- Machine learning applications
- AI/ML feature storage
- Recommendation systems