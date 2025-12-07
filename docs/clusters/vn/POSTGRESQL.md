# PostgreSQL on VN Cluster

## Overview

PostgreSQL is deployed on the VN cluster using CloudNativePG operator with high availability configuration.

## Internal Access

The PostgreSQL service is available internally at:
- **Service**: `postgresql-ha-rw.postgres-db`
- **Port**: 5432
- **Connection String**: `postgresql://be:***@postgresql-ha-rw.postgres-db:5432/murror`

## External Access

PostgreSQL is exposed to the internet via NodePort service.

### Connection Details

- **External IPs**: 
  - 14.225.210.108:30432
  - 14.225.210.165:30432
  - 14.225.210.170:30432
  - 14.225.210.189:30432
- **Port**: 30432
- **Database**: murror
- **Username**: be

### External Connection String

```
postgresql://be:***@14.225.210.108:30432/murror
```

You can use any of the external IPs listed above. The primary instance is currently running on node `vps33-vnix-nvme-dedicated-cpu` (14.225.210.189).

### Service Configuration

The external access is configured via NodePort service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgresql-ha-external
  namespace: postgres-db
  labels:
    cnpg.io/cluster: postgresql-ha
    service.type: external-access
spec:
  type: NodePort
  ports:
  - name: postgres
    port: 5432
    targetPort: 5432
    protocol: TCP
    nodePort: 30432
  selector:
    cnpg.io/cluster: postgresql-ha
    cnpg.io/instanceRole: primary
  sessionAffinity: None
```

## Security Considerations

⚠️ **WARNING**: The PostgreSQL database is now exposed to the internet. Ensure you:

1. **Use strong passwords** - The current password should be rotated regularly
2. **Implement firewall rules** - Consider restricting access to specific IP addresses
3. **Enable SSL/TLS** - Configure PostgreSQL to require encrypted connections
4. **Monitor access logs** - Check for unauthorized access attempts
5. **Regular backups** - Ensure automated backups are configured

## Verification

To verify external connectivity:

```bash
# Test connection from outside the cluster
psql "postgresql://be:***@14.225.210.108:30432/murror" -c "SELECT version();"

# Check service status
kubectl get svc -n postgres-db postgresql-ha-external

# Check primary pod
kubectl get pods -n postgres-db -l cnpg.io/instanceRole=primary
```

## Last Updated

- Date: 2025-08-24
- Service Type: NodePort
- NodePort: 30432