# murror-be Database Testing Connection Info

This document provides connection information for accessing the `murror-be` database with the read-only `tester` user.

## ⚠️ Important Security Notes

- **DEVELOPMENT ONLY**: This setup is for development and testing only
- **READ-ONLY ACCESS**: The `tester` user has SELECT permissions only
- **INTERNET EXPOSED**: The database is accessible from the internet via LoadBalancer
- **NO PRODUCTION DATA**: Ensure no production data is stored in this development database

## Connection Details

### Database Information
- **Host**: External IP from LoadBalancer (see commands below)
- **Port**: 5432
- **Database**: `murror-be`
- **Username**: `tester`
- **Password**: `<GET_FROM_KUBERNETES_SECRET>`
- **Permissions**: READ-ONLY (SELECT only)

### Getting the External IP

```bash
# Get the external IP address
kubectl get svc postgres-murror-be -n postgres-db -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Or with full service details
kubectl get svc postgres-murror-be -n postgres-db
```

## Connection Methods

### Using psql Command Line

```bash
# Get external IP first
EXTERNAL_IP=$(kubectl get svc postgres-murror-be -n postgres-db -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Connect with psql
PGPASSWORD="$(kubectl get secret tester-secret -n postgres-db -o jsonpath='{.data.password}' | base64 -d)" psql -h $EXTERNAL_IP -U tester -d murror-be -p 5432

# Or with connection string
psql "postgresql://tester:$(kubectl get secret tester-secret -n postgres-db -o jsonpath='{.data.password}' | base64 -d)@$EXTERNAL_IP:5432/murror-be"
```

### Using Connection String

```
postgresql://tester:<PASSWORD_FROM_SECRET>@<EXTERNAL_IP>:5432/murror-be
```

Replace `<EXTERNAL_IP>` with the actual IP from the LoadBalancer service and `<PASSWORD_FROM_SECRET>` with the password from the Kubernetes secret.

To get the password:
```bash
kubectl get secret tester-secret -n postgres-db -o jsonpath='{.data.password}' | base64 -d
```

### Application Configuration Examples

#### Python (psycopg2)
```python
import psycopg2

conn = psycopg2.connect(
    host="<EXTERNAL_IP>",
    database="murror-be",
    user="tester",
    password="<PASSWORD_FROM_SECRET>",
    port=5432
)
```

#### Node.js (pg)
```javascript
const { Client } = require('pg');

const client = new Client({
  host: '<EXTERNAL_IP>',
  database: 'murror-be',
  user: 'tester',
  password: '<PASSWORD_FROM_SECRET>',
  port: 5432,
});
```

#### Environment Variables
```bash
export PGHOST="<EXTERNAL_IP>"
export PGPORT="5432"
export PGDATABASE="murror-be"
export PGUSER="tester"
export PGPASSWORD="$(kubectl get secret tester-secret -n postgres-db -o jsonpath='{.data.password}' | base64 -d)"
```

## Permissions and Limitations

### What the tester user CAN do:
- SELECT from all existing tables in the murror-be database
- View table schemas and metadata
- Execute read-only queries
- Use database functions that don't modify data

### What the tester user CANNOT do:
- INSERT, UPDATE, DELETE data
- CREATE or DROP tables, indexes, or other objects
- Modify database schema
- Access other databases (murror-ai, default, vps-management)
- Execute administrative commands

## Testing Your Connection

### Quick Connection Test
```bash
# Test basic connectivity
EXTERNAL_IP=$(kubectl get svc postgres-murror-be -n postgres-db -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
PGPASSWORD="$(kubectl get secret tester-secret -n postgres-db -o jsonpath='{.data.password}' | base64 -d)" psql -h $EXTERNAL_IP -U tester -d murror-be -c "SELECT version();"
```

### Sample Queries
```sql
-- List all tables you have access to
SELECT schemaname, tablename
FROM pg_tables
WHERE schemaname NOT IN ('information_schema', 'pg_catalog');

-- Check your permissions
SELECT
    schemaname,
    tablename,
    privileges_string
FROM information_schema.role_table_grants
WHERE grantee = 'tester';

-- Sample data query (adjust table name as needed)
SELECT * FROM your_table_name LIMIT 10;
```

## Troubleshooting

### Connection Issues
1. **Service not ready**: Check if LoadBalancer has assigned an external IP
   ```bash
   kubectl get svc postgres-murror-be -n postgres-db -w
   ```

2. **Network connectivity**: Verify you can reach the external IP
   ```bash
   telnet <EXTERNAL_IP> 5432
   ```

3. **Authentication failed**: Verify username and password are correct

### Permission Denied
- The `tester` user only has read permissions
- You cannot modify data or schema
- You cannot access other databases

### Getting Help
1. Check cluster status:
   ```bash
   kubectl get cluster -n postgres-db
   kubectl get pods -n postgres-db
   ```

2. View PostgreSQL logs:
   ```bash
   kubectl logs -n postgres-db -l cnpg.io/instanceRole=primary -f
   ```

## Setup Commands

If you need to deploy or redeploy the testing access:

```bash
# Switch to dev cluster context
kubectl config use-context dev

# Apply the tester user configuration
kubectl apply -f cluster.yaml

# Apply secrets
kubectl apply -f secrets.yaml.local

# Deploy the LoadBalancer service
kubectl apply -f postgres-murror-be-loadbalancer.yaml

# Wait for external IP assignment
kubectl get svc postgres-murror-be -n postgres-db -w
```

## Security Best Practices

1. **Change password after testing**: Rotate the password after testing sessions
2. **Monitor access**: Check connection logs regularly
3. **Limit exposure time**: Remove LoadBalancer when not needed
4. **Use SSL connections**: Always use `sslmode=require` in production-like testing

## Cleanup

To remove external access when no longer needed:

```bash
# Remove LoadBalancer service
kubectl delete svc postgres-murror-be -n postgres-db

# Or remove the tester user entirely
kubectl patch cluster postgresql-ha -n postgres-db --type='json' \
  -p='[{"op": "remove", "path": "/spec/managed/roles/4"}]'
```

---

**Last Updated**: 2025-09-16
**Created By**: Infrastructure Team
**Environment**: Development
**Purpose**: Read-only testing access to murror-be database