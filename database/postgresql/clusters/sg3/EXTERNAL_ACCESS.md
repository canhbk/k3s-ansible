# PostgreSQL SG3 External Access (NodePort)

## Overview

The `postgresql-sg3-pgvector` PostgreSQL HA cluster is exposed externally via NodePort service for development and debugging access.

**Created**: 2025-12-11
**Service**: postgresql-sg3-pgvector-external
**NodePort**: 31432
**Cluster**: postgresql-sg3-pgvector (3-instance HA)

## Connection Information

### Access Endpoints

You can connect to the database using any node IP with port 31432:

**Internal Network** (10.10.0.0/24):
```
10.10.0.51:31432
10.10.0.52:31432
10.10.0.54:31432
10.10.0.56:31432
10.10.0.57:31432
```

**External IPs** (if firewall allows):
```
15.235.211.39:31432  (vps51)
15.235.197.174:31432 (vps52)
15.235.197.175:31432 (vps54)
15.235.211.111:31432 (vps56)
15.235.197.222:31432 (vps57)
```

### Available Users

| User | Purpose | Database | Get Password |
|------|---------|----------|--------------|
| postgres | Superuser | any | `kubectl get secret superuser-sg3-secret -n postgres-db -o jsonpath='{.data.password}' \| base64 -d` |
| app | Application user | app | `kubectl get secret app-sg3-secret -n postgres-db -o jsonpath='{.data.password}' \| base64 -d` |
| murror | Murror application | app | `kubectl get secret murror-sg3-secret -n postgres-db -o jsonpath='{.data.password}' \| base64 -d` |
| murror-ai | Murror AI application | app | `kubectl get secret murror-ai-sg3-secret -n postgres-db -o jsonpath='{.data.password}' \| base64 -d` |

## Connection Examples

### psql (PostgreSQL Client)

```bash
# Connect as app user
psql "postgresql://app:PASSWORD@10.10.0.51:31432/app"

# Connect as superuser
psql "postgresql://postgres:PASSWORD@10.10.0.51:31432/postgres"

# Connect with SSL (production recommendation)
psql "postgresql://app:PASSWORD@10.10.0.51:31432/app?sslmode=require"
```

### Connection String Format

```
postgresql://[user]:[password]@[node-ip]:31432/[database]
```

### DBeaver / DataGrip

- **Host**: 10.10.0.51 (or any node IP)
- **Port**: 31432
- **Database**: app
- **User**: app / murror / postgres
- **Password**: (retrieve from secret)
- **SSL**: Prefer or Require (production recommendation)

### Python (psycopg2)

```python
import psycopg2

conn = psycopg2.connect(
    host="10.10.0.51",
    port=31432,
    database="app",
    user="app",
    password="PASSWORD"
)
```

### Node.js (pg)

```javascript
const { Client } = require('pg');

const client = new Client({
  host: '10.10.0.51',
  port: 31432,
  database: 'app',
  user: 'app',
  password: 'PASSWORD'
});

await client.connect();
```

## Service Details

### Kubernetes Service Configuration

```yaml
Service: postgresql-sg3-pgvector-external
Namespace: postgres-db
Type: NodePort
Port: 5432 -> NodePort 31432
Selector: postgresql-sg3-pgvector (primary instance only)
Session Affinity: ClientIP (3-hour timeout)
```

### Check Service Status

```bash
# View service details
kubectl get svc postgresql-sg3-pgvector-external -n postgres-db

# Check endpoints (which pod is primary)
kubectl get endpoints postgresql-sg3-pgvector-external -n postgres-db

# View current primary pod
kubectl get pods -n postgres-db -l cnpg.io/cluster=postgresql-sg3-pgvector,cnpg.io/instanceRole=primary
```

## Important Notes

### High Availability Behavior

- **Primary-only access**: The NodePort service targets only the primary instance
- **Automatic failover**: If primary fails, CNPG promotes a replica and service redirects automatically
- **Session affinity**: ClientIP affinity ensures consistent routing for 3 hours
- **Connection interruption**: During failover, active connections will be dropped

### Read vs Write Operations

- **NodePort service**: Read-write access to primary instance only
- **Read-only needs**: Use internal ClusterIP services:
  - `postgresql-sg3-pgvector-ro.postgres-db.svc.cluster.local:5432` (read-only replicas)
  - `postgresql-sg3-pgvector-r.postgres-db.svc.cluster.local:5432` (all instances)

### Security Considerations

1. **Firewall rules**: Ensure NodePort 31432 is restricted to trusted IPs/networks
2. **Strong passwords**: All user passwords should be cryptographically strong
3. **SSL/TLS**: Enable SSL connections in production (`sslmode=require`)
4. **Network policies**: Consider implementing Kubernetes NetworkPolicy for additional security
5. **Audit logging**: Monitor database access logs for suspicious activity

### Troubleshooting

**Connection refused**:
```bash
# Check if service exists
kubectl get svc postgresql-sg3-pgvector-external -n postgres-db

# Verify pod is running
kubectl get pods -n postgres-db | grep postgresql-sg3

# Test node connectivity
nc -zv 10.10.0.51 31432
```

**Wrong instance/old data**:
```bash
# Check which pod is primary
kubectl get pods -n postgres-db -l cnpg.io/cluster=postgresql-sg3-pgvector,cnpg.io/instanceRole=primary -o wide
```

**Authentication failed**:
```bash
# Verify password from secret
kubectl get secret app-sg3-secret -n postgres-db -o jsonpath='{.data.password}' | base64 -d

# Check user exists in database
kubectl exec -it postgresql-sg3-pgvector-1 -n postgres-db -- psql -U postgres -c "\du"
```

## Removing External Access

If you need to remove external access:

```bash
# Delete the NodePort service
kubectl delete svc postgresql-sg3-pgvector-external -n postgres-db

# Database remains accessible internally via ClusterIP services
```

## References

- [PostgreSQL Cluster Configuration](./cluster-sg3-pgvector.yaml)
- [SG3 Services Documentation](../../docs/clusters/sg3/SERVICES.md)
- [PostgreSQL Exposure Guide](../../docs/services/postgresql/EXPOSURE.md)
- [CNPG Documentation](https://cloudnative-pg.io/)
