# pgAdmin Deployment - SG3 Cluster

## Overview

pgAdmin is deployed on the SG3 Kubernetes cluster to provide browser-based administration and management of PostgreSQL databases.

- **Version**: Latest (dpage/pgadmin4 Helm chart)
- **Deployment Date**: 2025-12-01
- **Namespace**: `postgres-db`
- **URL**: https://pgadmin.sg3.k3s.canhnv.com
- **High Availability**: 2 replicas with Longhorn persistent storage
- **Authentication**: pgAdmin built-in email/password authentication

## Architecture

- **Deployment**: 2 replicas with pod anti-affinity (distributed across nodes)
- **Storage**: Longhorn PVC (20Gi) for persistent configuration and data
- **Ingress**: Traefik with cert-manager TLS certificate
- **Resources**:
  - Requests: 250m CPU, 512Mi memory
  - Limits: 1000m CPU, 2Gi memory

## Pre-configured Database Connections

The following PostgreSQL servers are pre-configured and will appear automatically in pgAdmin:

### 1. postgresql-sg3-pgvector (Read-Write)
- **Host**: `postgresql-sg3-pgvector-rw.postgres-db.svc.cluster.local`
- **Port**: 5432
- **Database**: postgres
- **Username**: postgres
- **Description**: PostgreSQL 17.2 HA cluster with pgvector - Primary read-write endpoint

### 2. postgresql-sg3-pgvector-readonly (Read-Only)
- **Host**: `postgresql-sg3-pgvector-ro.postgres-db.svc.cluster.local`
- **Port**: 5432
- **Database**: postgres
- **Username**: postgres
- **Description**: PostgreSQL 17.2 HA cluster - Read-only replicas endpoint

## Deployment Steps

### Prerequisites

Ensure you have access to the sg3 cluster:

```bash
kubectl config use-context sg3
kubectl get nodes
```

### Step 1: Create Admin Secret

Generate a secure password and create the pgAdmin admin secret:

```bash
# Generate secure password
PGADMIN_PASSWORD=$(openssl rand -base64 32)

# Create secret
kubectl create secret generic pgadmin-admin \
  --from-literal=password="$PGADMIN_PASSWORD" \
  -n postgres-db

# Display password for your records (save this securely!)
echo "pgAdmin admin password: $PGADMIN_PASSWORD"
```

### Step 2: Add pgAdmin Helm Repository

```bash
helm repo add pgadmin https://helm.runix.net
helm repo update
```

### Step 3: Deploy pgAdmin with Helm

```bash
cd /Users/canhnv/development/canhnv/k3s-ansible

helm install pgadmin pgadmin/pgadmin4 \
  -f pgadmin/clusters/sg3/values.yaml \
  -n postgres-db \
  --wait
```

### Step 4: Apply ConfigMap and Ingress

```bash
# Apply server configuration ConfigMap
kubectl apply -f pgadmin/clusters/sg3/pgadmin-config.yaml

# Apply Traefik ingress
kubectl apply -f pgadmin/clusters/sg3/ingress.yaml
```

### Step 5: Verify Deployment

```bash
# Check deployment status
kubectl get deployments -n postgres-db | grep pgadmin

# Check pods
kubectl get pods -n postgres-db -l app.kubernetes.io/name=pgadmin4

# Check service
kubectl get svc -n postgres-db | grep pgadmin

# Check ingress
kubectl get ingress -n postgres-db

# Check PVC
kubectl get pvc -n postgres-db | grep pgadmin

# Check TLS certificate
kubectl get certificate -n postgres-db
kubectl describe certificate pgadmin-sg3-tls -n postgres-db
```

### Step 6: Access pgAdmin

1. Wait for the TLS certificate to be issued (usually 1-2 minutes)
2. Navigate to https://pgadmin.sg3.k3s.canhnv.com
3. Login with:
   - **Email**: admin@canhnv.com
   - **Password**: (the password from Step 1)

## Post-Deployment Configuration

### Connecting to Pre-configured Databases

The PostgreSQL connections are pre-configured but you'll need to enter the password on first use:

1. In pgAdmin, expand "Servers" in the left sidebar
2. Click on "postgresql-sg3-pgvector"
3. Enter the postgres user password (from the PostgreSQL cluster secret)
4. The connection will be saved for future use

To retrieve the postgres password:

```bash
kubectl get secret superuser-sg3-secret -n postgres-db \
  -o jsonpath='{.data.password}' | base64 -d
echo
```

### Adding Additional Database Connections Manually

To add more database connections (for example, using the `app`, `murror`, or `murror-ai` users):

1. Right-click "Servers" → "Register" → "Server"
2. **General tab**:
   - Name: (e.g., "postgresql-sg3-pgvector-app")
   - Server group: "SG3 Cluster"
3. **Connection tab**:
   - Host: `postgresql-sg3-pgvector-rw.postgres-db.svc.cluster.local`
   - Port: 5432
   - Maintenance database: `app` (or `postgres`)
   - Username: `app` (or `murror`, `murror-ai`)
   - Password: (retrieve from respective secrets)
4. Click "Save"

To retrieve user passwords:

```bash
# app user password
kubectl get secret app-sg3-secret -n postgres-db \
  -o jsonpath='{.data.password}' | base64 -d
echo

# murror user password
kubectl get secret murror-sg3-secret -n postgres-db \
  -o jsonpath='{.data.password}' | base64 -d
echo

# murror-ai user password
kubectl get secret murror-ai-sg3-secret -n postgres-db \
  -o jsonpath='{.data.password}' | base64 -d
echo
```

## Maintenance

### Viewing Logs

```bash
kubectl logs -n postgres-db -l app.kubernetes.io/name=pgadmin4 --tail=100 -f
```

### Upgrading pgAdmin

```bash
# Update Helm repository
helm repo update

# Check current version
helm list -n postgres-db | grep pgadmin

# Upgrade to latest version
helm upgrade pgadmin pgadmin/pgadmin4 \
  -f pgadmin/clusters/sg3/values.yaml \
  -n postgres-db \
  --wait
```

### Scaling Replicas

Edit `values.yaml` and update `replicaCount`, then upgrade:

```bash
helm upgrade pgadmin pgadmin/pgadmin4 \
  -f pgadmin/clusters/sg3/values.yaml \
  -n postgres-db \
  --wait
```

### Changing Admin Password

```bash
# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# Update secret
kubectl patch secret pgadmin-admin -n postgres-db \
  -p "{\"data\":{\"password\":\"$(echo -n $NEW_PASSWORD | base64)\"}}"

# Restart pgAdmin pods to pick up new password
kubectl rollout restart deployment pgadmin-pgadmin4 -n postgres-db

# Display new password
echo "New pgAdmin admin password: $NEW_PASSWORD"
```

## Troubleshooting

### pgAdmin Pods Not Starting

Check pod status and events:

```bash
kubectl describe pod -n postgres-db -l app.kubernetes.io/name=pgadmin4
kubectl logs -n postgres-db -l app.kubernetes.io/name=pgadmin4
```

### PVC Not Mounting

Check PVC status:

```bash
kubectl get pvc -n postgres-db | grep pgadmin
kubectl describe pvc <pvc-name> -n postgres-db
```

### Ingress Not Working

Check ingress and certificate:

```bash
kubectl describe ingress pgadmin -n postgres-db
kubectl describe certificate pgadmin-sg3-tls -n postgres-db
kubectl get certificate -n postgres-db
```

Check cert-manager logs if certificate is not being issued:

```bash
kubectl logs -n cert-manager -l app=cert-manager --tail=100
```

### Cannot Connect to PostgreSQL

Verify network connectivity from pgAdmin pod:

```bash
# Get pgAdmin pod name
POD_NAME=$(kubectl get pods -n postgres-db -l app.kubernetes.io/name=pgadmin4 -o jsonpath='{.items[0].metadata.name}')

# Test connection to PostgreSQL
kubectl exec -n postgres-db $POD_NAME -- nc -zv postgresql-sg3-pgvector-rw.postgres-db.svc.cluster.local 5432
```

### Password Not Working

Verify the admin secret:

```bash
kubectl get secret pgadmin-admin -n postgres-db \
  -o jsonpath='{.data.password}' | base64 -d
echo
```

## Backup and Restore

pgAdmin configuration (server connections, query history, preferences) is stored in the Longhorn PVC. Ensure Longhorn backup policies include the `postgres-db` namespace.

To manually backup pgAdmin configuration:

```bash
# Export pgAdmin configuration
kubectl exec -n postgres-db <pgadmin-pod> -- tar czf - /var/lib/pgadmin > pgadmin-backup.tar.gz
```

To restore:

```bash
# Restore pgAdmin configuration
kubectl exec -n postgres-db <pgadmin-pod> -- tar xzf - -C / < pgadmin-backup.tar.gz
```

## Security Considerations

- **HTTPS Only**: All traffic is encrypted via TLS (cert-manager)
- **Session Cookies**: Secure, HttpOnly, SameSite=Lax
- **Admin Password**: Stored in Kubernetes secret (not in Git)
- **Database Passwords**: Not stored in pgAdmin (prompted on first connection)
- **Network Isolation**: ClusterIP service (no external LoadBalancer)
- **CSRF Protection**: Enabled by default

**Important**: Change the default admin password immediately after first login!

## Uninstallation

To remove pgAdmin from the cluster:

```bash
# Uninstall Helm release
helm uninstall pgadmin -n postgres-db

# Delete ConfigMap and Ingress
kubectl delete -f pgadmin/clusters/sg3/pgadmin-config.yaml
kubectl delete -f pgadmin/clusters/sg3/ingress.yaml

# Delete admin secret
kubectl delete secret pgadmin-admin -n postgres-db

# Delete PVC (if you want to remove all data)
kubectl delete pvc -n postgres-db -l app.kubernetes.io/name=pgadmin4
```

## References

- [pgAdmin Official Documentation](https://www.pgadmin.org/docs/)
- [pgAdmin Helm Chart](https://github.com/rowanruseler/helm-charts/tree/main/charts/pgadmin4)
- [PostgreSQL SG3 Cluster Documentation](../../database/postgresql/clusters/sg3/README.md)
- [SG3 Cluster Overview](../../docs/clusters/sg3/README.md)
