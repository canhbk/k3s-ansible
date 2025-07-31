# PostgreSQL Exposure Guide

This guide covers how to expose PostgreSQL databases in different environments with appropriate security measures.

## Environment-Specific Guidelines

### 🟢 Development Environment

**Acceptable Methods**: LoadBalancer, NodePort, Port Forwarding

#### Quick Access via Port Forwarding

Best for temporary access during development:

```bash
# Forward PostgreSQL to local machine
kubectl port-forward -n postgres-db svc/postgresql-ha-rw 5432:5432

# In another terminal, connect
psql -h localhost -p 5432 -U dev -d default
```

#### Persistent Access via LoadBalancer

For team development access:

```yaml
# postgres-dev-loadbalancer.yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres-external
  namespace: postgres-db
  annotations:
    environment: "development"
    created-by: "your-name"
    purpose: "team-development-access"
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
  # IMPORTANT: Add your team's IPs
  loadBalancerSourceRanges:
  - "203.0.113.0/24"    # Office network
  - "198.51.100.14/32"  # Developer home IP
  - "192.0.2.0/24"      # VPN range
```

Apply and get connection details:

```bash
# Apply the service
kubectl apply -f postgres-dev-loadbalancer.yaml

# Wait for external IP
kubectl get svc -n postgres-db postgres-external -w

# Get connection info
kubectl get svc -n postgres-db postgres-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### 🟡 Staging Environment

**Acceptable Methods**: VPN Access, Bastion Host, Private Network

#### VPN-Based Access

```yaml
# postgres-staging-internal.yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres-internal
  namespace: postgres-db
  annotations:
    environment: "staging"
    access: "vpn-only"
spec:
  type: ClusterIP  # Internal only
  selector:
    cnpg.io/cluster: postgresql-ha
    cnpg.io/instanceRole: primary
  ports:
  - port: 5432
    targetPort: 5432
---
# NetworkPolicy to restrict access
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgres-vpn-only
  namespace: postgres-db
spec:
  podSelector:
    matchLabels:
      cnpg.io/cluster: postgresql-ha
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: staging-apps
    - podSelector:
        matchLabels:
          vpn-gateway: "true"
    ports:
    - protocol: TCP
      port: 5432
```

### 🔴 Production Environment

**Acceptable Methods**: Private Network Only, Application-to-Application

#### Never Expose Directly!

Production databases should NEVER be exposed to the internet. Use:

1. **Application-Only Access**
   ```yaml
   # Strict NetworkPolicy
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: postgres-production
     namespace: postgres-db
   spec:
     podSelector:
       matchLabels:
         cnpg.io/cluster: postgresql-ha
     policyTypes:
     - Ingress
     - Egress
     ingress:
     - from:
       - namespaceSelector:
           matchLabels:
             environment: production
         podSelector:
           matchLabels:
             db-access: "authorized"
       ports:
       - protocol: TCP
         port: 5432
   ```

2. **Emergency Access via Bastion**
   ```bash
   # SSH to bastion host first
   ssh user@bastion.company.com
   
   # From bastion, kubectl port-forward
   kubectl port-forward -n postgres-db svc/postgresql-ha-rw 5432:5432
   
   # From your local machine, SSH tunnel
   ssh -L 5432:localhost:5432 user@bastion.company.com
   ```

## Step-by-Step Exposure Guide

### Prerequisites

1. **Verify Cluster Context**
   ```bash
   kubectl config current-context
   # Should show: dev, staging, or prod
   ```

2. **Check PostgreSQL Status**
   ```bash
   kubectl get pods -n postgres-db
   kubectl get svc -n postgres-db
   ```

3. **Gather IP Addresses**
   - Your office IP: `curl ifconfig.me`
   - Team member IPs
   - VPN IP ranges

### For Development Cluster

1. **Create LoadBalancer Service**

   Create file `postgres-loadbalancer.yaml`:
   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: postgres-dev-external
     namespace: postgres-db
     labels:
       app: postgresql
       environment: development
     annotations:
       service.beta.kubernetes.io/do-loadbalancer-name: "postgres-dev"
       service.beta.kubernetes.io/do-loadbalancer-size-unit: "1"
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
     sessionAffinity: ClientIP
     loadBalancerSourceRanges:
     - "YOUR.IP.HERE/32"  # Replace with actual IPs
   ```

2. **Apply and Monitor**
   ```bash
   # Apply the service
   kubectl apply -f postgres-loadbalancer.yaml
   
   # Watch for external IP assignment
   kubectl get svc -n postgres-db postgres-dev-external -w
   
   # Describe for details
   kubectl describe svc -n postgres-db postgres-dev-external
   ```

3. **Test Connection**
   ```bash
   # Get the external IP
   EXTERNAL_IP=$(kubectl get svc -n postgres-db postgres-dev-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
   
   # Get password
   DB_PASS=$(kubectl get secret -n postgres-db dev-secret -o jsonpath='{.data.password}' | base64 -d)
   
   # Test connection
   PGPASSWORD=$DB_PASS psql -h $EXTERNAL_IP -U dev -d default -c "SELECT version();"
   ```

4. **Configure Firewall (Optional)**
   ```bash
   # If using cloud provider firewall
   # Example for DigitalOcean
   doctl compute firewall create \
     --name postgres-dev \
     --inbound-rules "protocol:tcp,ports:5432,sources:addresses:YOUR.IP.HERE/32"
   ```

### Connection String Templates

#### Development
```bash
# Basic connection
postgresql://username:password@external-ip:5432/database

# With SSL (recommended)
postgresql://username:password@external-ip:5432/database?sslmode=require

# With connection pooling
postgresql://username:password@external-ip:5432/database?pool_max_conns=10
```

#### Application Configuration
```yaml
# ConfigMap for application
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-db-config
data:
  DATABASE_URL: "postgresql://user:password@postgres-external:5432/mydb?sslmode=require"
  DB_POOL_SIZE: "20"
  DB_TIMEOUT: "30s"
```

## Security Checklist

Before exposing PostgreSQL:

### Development
- [ ] IP allowlist configured in `loadBalancerSourceRanges`
- [ ] Non-production data only
- [ ] Separate passwords from production
- [ ] Monitoring enabled
- [ ] Regular password rotation scheduled

### Staging/Production
- [ ] No direct internet exposure
- [ ] VPN or bastion access only
- [ ] Network policies in place
- [ ] Audit logging enabled
- [ ] SSL/TLS enforced
- [ ] Backup strategy implemented
- [ ] Incident response plan ready

## Monitoring Exposed Services

### Check Active Connections
```bash
# List all connections
kubectl exec -it -n postgres-db postgresql-ha-1 -- psql -U postgres -c "
SELECT pid, usename, client_addr, state, query_start 
FROM pg_stat_activity 
WHERE client_addr IS NOT NULL;"

# Monitor connection count
watch -n 5 'kubectl exec -n postgres-db postgresql-ha-1 -- psql -U postgres -t -c "SELECT count(*) FROM pg_stat_activity;"'
```

### Setup Alerts
```yaml
# Example PrometheusRule for connection monitoring
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: postgres-connection-alerts
spec:
  groups:
  - name: postgres
    rules:
    - alert: TooManyConnections
      expr: pg_stat_activity_count > 100
      for: 5m
      annotations:
        summary: "Too many PostgreSQL connections"
```

## Troubleshooting

### LoadBalancer Not Getting IP
```bash
# Check events
kubectl describe svc -n postgres-db postgres-external

# Check cloud provider
kubectl get events -n postgres-db --field-selector involvedObject.name=postgres-external

# Verify cloud provider integration
kubectl logs -n kube-system -l app=cloud-controller-manager
```

### Connection Refused
1. Check service endpoints:
   ```bash
   kubectl get endpoints -n postgres-db postgres-external
   ```

2. Verify pod is running:
   ```bash
   kubectl get pods -n postgres-db -l cnpg.io/instanceRole=primary
   ```

3. Check firewall rules:
   ```bash
   # Verify loadBalancerSourceRanges
   kubectl get svc -n postgres-db postgres-external -o yaml | grep -A5 loadBalancerSourceRanges
   ```

### Performance Issues
```bash
# Check current connections
kubectl exec -it -n postgres-db postgresql-ha-1 -- psql -U postgres -c "
SELECT count(*), state 
FROM pg_stat_activity 
GROUP BY state;"

# Check slow queries
kubectl exec -it -n postgres-db postgresql-ha-1 -- psql -U postgres -c "
SELECT query, state, wait_event_type, wait_event 
FROM pg_stat_activity 
WHERE state != 'idle' 
ORDER BY query_start;"
```

## Cleanup

### Remove External Access
```bash
# Delete LoadBalancer service
kubectl delete svc -n postgres-db postgres-external

# Verify removal
kubectl get svc -n postgres-db

# Clean up any firewall rules
# Example for cloud provider
doctl compute firewall delete postgres-dev
```

### Audit Trail
```bash
# Log the removal
echo "$(date): Removed PostgreSQL external access" >> ~/postgres-access-log.txt

# Notify team
echo "PostgreSQL external access has been removed from dev cluster" | mail -s "DB Access Update" team@company.com
```

## Best Practices

1. **Always Use IP Allowlisting**: Never expose without `loadBalancerSourceRanges`
2. **Rotate Credentials**: Change passwords after exposure
3. **Monitor Access**: Set up alerts for unusual connection patterns
4. **Document Changes**: Keep track of who has access and why
5. **Regular Reviews**: Audit exposed services weekly
6. **Use SSL/TLS**: Always encrypt connections, even in dev
7. **Implement Timeouts**: Set connection and statement timeouts

## Related Documentation

- [PostgreSQL Setup](./SETUP.md)
- [PostgreSQL Security](./SECURITY.md)
- [Dev Cluster PostgreSQL](../../clusters/dev/POSTGRESQL.md)
- [Security Guidelines](../../SECURITY_GUIDELINES.md)