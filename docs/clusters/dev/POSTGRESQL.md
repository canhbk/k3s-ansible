# PostgreSQL on Dev Cluster

## Overview

The development cluster runs a PostgreSQL HA instance using CloudNative PG operator with pgvector extension for AI workloads.

## Current Configuration

### Cluster Details

- **Namespace**: `postgres-db`
- **Operator**: CloudNative PG v1.26.0
- **PostgreSQL Version**: 17 with pgvector 0.8.0
- **Instance Count**: 1 (development mode)
- **Storage**: 10Gi local-path

### Services

| Service | Type | Purpose | Internal Endpoint |
|---------|------|---------|-------------------|
| postgresql-ha-rw | ClusterIP | Read-Write (Primary) | postgresql-ha-rw.postgres-db.svc.cluster.local:5432 |
| postgresql-ha-ro | ClusterIP | Read-Only | postgresql-ha-ro.postgres-db.svc.cluster.local:5432 |
| postgresql-ha-r | ClusterIP | Read Replicas | postgresql-ha-r.postgres-db.svc.cluster.local:5432 |
| postgres-murror-ai | LoadBalancer | AI Team External Access | 154.26.131.23:5432 (and 6 other IPs) |
| postgres-murror-be-nodeport | NodePort | BE Team External Access | Any node IP:30543 |

### Databases and Users

| Database | Owner | Purpose |
|----------|-------|---------|
| default | dev | General development database |
| murror-ai | ai | AI workloads with pgvector |
| murror-be | be | Backend services |

| User | Type | Access Level | Secret Name |
|------|------|--------------|-------------|
| postgres | Superuser | Full admin access | superuser-secret |
| dev | Application | Database owner (default) | dev-secret |
| ai | Application | Database owner (murror-ai) | ai-secret |
| be | Application | Database owner (murror-be) | be-secret |

## Accessing PostgreSQL

### Internal Access (Within Cluster)

Applications within the cluster can connect using the service DNS names:

```yaml
# Example ConfigMap for application
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: my-app
data:
  DB_HOST: postgresql-ha-rw.postgres-db.svc.cluster.local
  DB_PORT: "5432"
  DB_NAME: murror-ai
  DB_USER: ai
```

### External Access for Development

#### Option 1: Port Forwarding (Recommended for Quick Access)

```bash
# Forward PostgreSQL to local port
kubectl port-forward -n postgres-db svc/postgresql-ha-rw 5432:5432

# Connect with psql
psql -h localhost -p 5432 -U dev -d default

# Connect with connection string
psql "postgresql://dev:$(kubectl get secret -n postgres-db dev-secret -o jsonpath='{.data.password}' | base64 -d)@localhost:5432/default"
```

#### Option 2: LoadBalancer Service (For Persistent Access)

Create a LoadBalancer service for development access:

```bash
# Create the LoadBalancer service
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: postgres-dev-external
  namespace: postgres-db
  annotations:
    environment: "development"
    warning: "DO NOT USE IN PRODUCTION"
spec:
  type: LoadBalancer
  selector:
    cnpg.io/cluster: postgresql-ha
    cnpg.io/instanceRole: primary
  ports:
  - port: 5432
    targetPort: 5432
    protocol: TCP
    name: postgres
  # IMPORTANT: Restrict to your IP addresses
  loadBalancerSourceRanges:
  - "YOUR.OFFICE.IP/32"      # Replace with your office IP
  - "YOUR.HOME.IP/32"        # Replace with your home IP
EOF

# Wait for external IP
kubectl get svc -n postgres-db postgres-dev-external -w

# Get the external IP
EXTERNAL_IP=$(kubectl get svc -n postgres-db postgres-dev-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "PostgreSQL available at: $EXTERNAL_IP:5432"
```

## Getting Credentials

```bash
# Get passwords for each user
# Superuser (postgres)
kubectl get secret -n postgres-db superuser-secret -o jsonpath='{.data.password}' | base64 -d

# Dev user
kubectl get secret -n postgres-db dev-secret -o jsonpath='{.data.password}' | base64 -d

# AI user
kubectl get secret -n postgres-db ai-secret -o jsonpath='{.data.password}' | base64 -d

# BE user
kubectl get secret -n postgres-db be-secret -o jsonpath='{.data.password}' | base64 -d
```

## Connection Examples

### Using psql

```bash
# Connect to default database as dev user
psql -h $EXTERNAL_IP -p 5432 -U dev -d default

# Connect to murror-ai database as ai user
psql -h $EXTERNAL_IP -p 5432 -U ai -d murror-ai

# Connect to murror-be database as be user
psql -h $EXTERNAL_IP -p 5432 -U be -d murror-be
```

### Connection Strings

```bash
# Default database (dev user)
postgresql://dev:PASSWORD@EXTERNAL_IP:5432/default

# AI database with pgvector
postgresql://ai:PASSWORD@EXTERNAL_IP:5432/murror-ai

# Backend database
postgresql://be:PASSWORD@EXTERNAL_IP:5432/murror-be

# With SSL (recommended even for dev)
postgresql://user:PASSWORD@EXTERNAL_IP:5432/database?sslmode=require
```

### Application Examples

#### Python (psycopg2)

```python
import psycopg2

conn = psycopg2.connect(
    host="EXTERNAL_IP",
    port=5432,
    database="murror-ai",
    user="ai",
    password="PASSWORD"
)
```

#### Node.js (pg)

```javascript
const { Client } = require('pg');

const client = new Client({
  host: 'EXTERNAL_IP',
  port: 5432,
  database: 'murror-be',
  user: 'be',
  password: 'PASSWORD',
});

await client.connect();
```

#### Go (pq)

```go
import (
    "database/sql"
    _ "github.com/lib/pq"
)

db, err := sql.Open("postgres",
    "host=EXTERNAL_IP port=5432 user=dev dbname=default password=PASSWORD sslmode=disable")
```

## Working with pgvector

The AI database has pgvector extension enabled:

```sql
-- Connect to murror-ai database
psql -h $EXTERNAL_IP -p 5432 -U ai -d murror-ai

-- Create a table with vector column
CREATE TABLE embeddings (
    id SERIAL PRIMARY KEY,
    content TEXT,
    embedding vector(1536)  -- for OpenAI embeddings
);

-- Create an index for similarity search
CREATE INDEX ON embeddings
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- Insert vector data
INSERT INTO embeddings (content, embedding)
VALUES ('sample text', '[0.1, 0.2, 0.3, ...]'::vector);

-- Similarity search
SELECT content, embedding <=> '[0.1, 0.2, 0.3, ...]'::vector AS distance
FROM embeddings
ORDER BY distance
LIMIT 10;
```

## Monitoring and Maintenance

### Check PostgreSQL Status

```bash
# Check pod status
kubectl get pods -n postgres-db

# Check cluster status
kubectl get cluster.postgresql.cnpg.io -n postgres-db

# View PostgreSQL logs
kubectl logs -n postgres-db postgresql-ha-1 -f

# Describe the cluster
kubectl describe cluster.postgresql.cnpg.io -n postgres-db postgresql-ha
```

### Common Operations

```bash
# Execute SQL directly
kubectl exec -it -n postgres-db postgresql-ha-1 -- psql -U postgres -d default

# Backup database (manual)
kubectl exec -n postgres-db postgresql-ha-1 -- pg_dump -U postgres default > backup.sql

# Check connections
kubectl exec -it -n postgres-db postgresql-ha-1 -- psql -U postgres -c "SELECT * FROM pg_stat_activity;"
```

## Troubleshooting

### Connection Issues

1. **Cannot connect externally**
   - Check LoadBalancer service status: `kubectl get svc -n postgres-db`
   - Verify IP restrictions in `loadBalancerSourceRanges`
   - Check firewall rules on your local machine

2. **Authentication failed**
   - Verify password: `kubectl get secret -n postgres-db USER-secret -o jsonpath='{.data.password}' | base64 -d`
   - Check username spelling
   - Ensure connecting to correct database

3. **Database does not exist**
   - List databases: `kubectl exec -it -n postgres-db postgresql-ha-1 -- psql -U postgres -l`
   - Create database if needed: `CREATE DATABASE mydb OWNER myuser;`

### Performance Issues

```bash
# Check resource usage
kubectl top pod -n postgres-db

# View slow queries
kubectl exec -it -n postgres-db postgresql-ha-1 -- psql -U postgres -c "
SELECT query, calls, mean_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;"
```

### Secret/Password Mismatch Issues

If you encounter authentication errors after cluster rebuilds or secret updates, follow these steps:

**Symptom**: Applications fail with "Authentication failed" even though the secret appears correct.

**Root Cause**: The Kubernetes secret and the actual PostgreSQL user password are out of sync. This commonly happens after:
- Cluster rebuilds (especially using `k3s-uninstall.sh`)
- Manual secret updates without updating PostgreSQL
- Applying secrets with placeholder values

**Solution**:

1. **Verify the secret contains the actual password (not a placeholder)**:
   ```bash
   kubectl get secret -n postgres-db be-secret -o jsonpath='{.data.password}' | base64 -d
   ```

   If you see `<CHANGE_ME_BE_PASSWORD>` or similar placeholder, the secret needs updating.

2. **Apply the correct secrets from the secrets.yaml.local file**:
   ```bash
   kubectl apply -f database/postgresql/clusters/dev/secrets.yaml.local -n postgres-db
   ```

3. **Update the PostgreSQL user password to match the secret**:
   ```bash
   # Get the correct password from the secret
   NEW_PASSWORD=$(kubectl get secret -n postgres-db be-secret -o jsonpath='{.data.password}' | base64 -d)

   # Update the user password in PostgreSQL
   kubectl exec -n postgres-db postgresql-ha-1 -- psql -U postgres -c "ALTER USER be WITH PASSWORD '$NEW_PASSWORD';"
   ```

4. **Test the connection**:
   ```bash
   kubectl run -n nsp-alpha-murror psql-test --rm -i --tty --image=postgres:17 --restart=Never \
     --env="PGPASSWORD=$NEW_PASSWORD" -- \
     psql -h postgresql-ha-rw.postgres-db.svc.cluster.local -U be -d murror-be -c "SELECT version();"
   ```

5. **Restart application pods** to pick up the correct credentials:
   ```bash
   kubectl delete pods -n nsp-alpha-murror -l app=murror-migration
   ```

**Prevention**: After any cluster rebuild:
1. Always apply secrets before creating the PostgreSQL cluster
2. Verify all user passwords match their Kubernetes secrets
3. Test authentication before deploying applications

**Last Incident**: 2025-11-03 - Fixed password mismatch after cluster rebuild on 2025-11-02

### Schema Permission Issues

If migrations fail with "permission denied for schema public", the user needs proper database ownership.

**Symptom**: Migration coordinators or ORM tools fail with:
```
ERROR: permission denied for schema public
LINE 2:   CREATE TABLE IF NOT EXISTS migration_coordination (
```

**Root Cause**: In PostgreSQL 15+, databases created via SQL commands inherit ownership from the `postgres` superuser. Non-superuser application users (like `ai`, `be`, `vps`) lack CREATE privileges on the `public` schema by default.

**Solution**:

1. **Transfer database ownership to the application user** (Recommended):
   ```bash
   # For AI database
   kubectl exec -n postgres-db postgresql-ha-1 -- psql -U postgres -c "ALTER DATABASE \"murror-ai\" OWNER TO ai;"

   # For BE database
   kubectl exec -n postgres-db postgresql-ha-1 -- psql -U postgres -c "ALTER DATABASE \"murror-be\" OWNER TO be;"

   # For VPS database
   kubectl exec -n postgres-db postgresql-ha-1 -- psql -U postgres -c "ALTER DATABASE \"vps-management\" OWNER TO vps;"
   ```

2. **Verify database ownership**:
   ```bash
   kubectl exec -n postgres-db postgresql-ha-1 -- psql -U postgres -c "\l+"
   ```

3. **Test permissions**:
   ```bash
   # Test AI user
   kubectl run -n nsp-alpha-murror-ai psql-ai-test --rm -i --tty --image=postgres:17 --restart=Never \
     --env="PGPASSWORD=$(kubectl get secret -n postgres-db ai-secret -o jsonpath='{.data.password}' | base64 -d)" -- \
     psql -h postgresql-ha-rw.postgres-db.svc.cluster.local -U ai -d murror-ai \
     -c "CREATE TABLE _test (id serial); DROP TABLE _test; SELECT 'Success';"

   # Test BE user
   kubectl run -n nsp-alpha-murror psql-test --rm -i --tty --image=postgres:17 --restart=Never \
     --env="PGPASSWORD=$(kubectl get secret -n postgres-db be-secret -o jsonpath='{.data.password}' | base64 -d)" -- \
     psql -h postgresql-ha-rw.postgres-db.svc.cluster.local -U be -d murror-be \
     -c "CREATE TABLE _test (id serial); DROP TABLE _test; SELECT 'Success';"
   ```

4. **Restart migration pods** to trigger migrations:
   ```bash
   # Delete failed migration jobs
   kubectl delete job -n nsp-alpha-murror-ai murror-ai-migration-coordinator
   kubectl delete job -n nsp-alpha-murror murror-migration-coordinator
   ```

**Prevention**: The cluster configuration (`database/postgresql/clusters/dev/cluster.yaml`) has been updated to automatically assign database ownership during cluster creation. This fix will apply automatically on future cluster rebuilds.

**Incident History**:
- **2025-11-03 (Latest)**: Fixed database ownership for `ai` user in `murror-ai` database after AI migration coordinator failures
- **2025-11-03**: Fixed schema ownership for `be` user in `murror-be` database
- **Root Issue**: Databases created after cluster rebuild on 2025-11-02 had incorrect ownership

## Current External Access

### AI Team Access (Active)

- **Service**: `postgres-murror-ai`
- **Type**: LoadBalancer (Open to Internet)
- **Created**: 2025-07-31
- **Database**: murror-ai only
- **User**: ai
- **External IPs**: 154.26.131.23, 154.38.172.89, 209.126.10.183, 46.250.232.10, 5.104.86.195
- **Purpose**: AI team development with pgvector

To remove this access:

```bash
kubectl delete svc -n postgres-db postgres-murror-ai
```

### BE Team Access (Active)

- **Service**: `postgres-murror-be-nodeport`
- **Type**: NodePort (Open to Internet)
- **Created**: 2025-08-22
- **Database**: murror-be
- **User**: be
- **NodePort**: 30543
- **External Access**: Available on all node IPs at port 30543
  - 154.26.131.23:30543
  - 46.250.232.10:30543
  - 5.104.86.195:30543
  - 160.191.245.234:30543
  - 163.61.110.120:30543
  - 160.250.136.247:30543
  - 163.61.110.117:30543
- **Purpose**: Backend team development access

Connection string example:
```
postgresql://be:__REDACTED__@154.26.131.23:30543/murror-be?schema=public
```

To remove this access:

```bash
kubectl delete svc -n postgres-db postgres-murror-be-nodeport
```

## Security Considerations

⚠️ **Development Only**: The LoadBalancer exposure is for development only. In production:

- Use VPN or bastion hosts
- Implement network policies
- Use SSL/TLS connections
- Rotate credentials regularly
- Monitor access logs

## Cleanup

To remove external access:

```bash
# Delete LoadBalancer service
kubectl delete svc -n postgres-db postgres-dev-external

# Verify it's removed
kubectl get svc -n postgres-db
```

## Related Documentation

- [CloudNative PG Documentation](https://cloudnative-pg.io/documentation/)
- [pgvector Documentation](https://github.com/pgvector/pgvector)
- [Dev Cluster Overview](./README.md)
- [Security Guidelines](../../SECURITY_GUIDELINES.md#development-database-access)
