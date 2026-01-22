# Auth Service - SG3 Cluster (Alpha)

## Overview

The Auth Service is a NestJS-based authentication and authorization service deployed to the SG3 cluster as part of the AmberCare Alpha environment. It provides JWT-based authentication, OAuth 2.0 support, and user management capabilities.

**Deployed**: January 14, 2025
**Environment**: Alpha (Staging)
**Namespace**: murror-platform
**Source**: [murror-platform/apps/auth-service](https://github.com/Murror/murror-platform)

## Access Information

### External Access

| Endpoint | URL |
|----------|-----|
| **API Base** | https://auth-alpha.ambercare.app |
| **Health Check** | https://auth-alpha.ambercare.app/api/health |
| **API Docs** | https://auth-alpha.ambercare.app/api/docs |

### Internal Access (within cluster)

```bash
# Service endpoint
auth-service.murror-platform.svc.cluster.local:3002

# Health check
curl http://auth-service.murror-platform.svc.cluster.local:3002/api/health
```

## Configuration

### Database

| Property | Value |
|----------|-------|
| **Database** | `murror_auth_service` |
| **User** | `murror_auth_service` |
| **Host** | `postgresql-sg3-pgvector-rw.postgres-db.svc.cluster.local` |
| **Port** | `5432` |

### Deployment

| Property | Value |
|----------|-------|
| **Namespace** | `murror-platform` |
| **Replicas** | 1 (Alpha) |
| **Port** | 3002 |
| **Health Endpoint** | `/api/health` |

### Ingress

| Property | Value |
|----------|-------|
| **Domain** | `auth-alpha.ambercare.app` |
| **Ingress Class** | traefik |
| **TLS** | Let's Encrypt (ambercare-app ClusterIssuer) |

## Admin User Seeding

The Auth Service is configured with automatic admin user seeding on startup. This creates a default administrator account for managing the application.

### Seeding Configuration

| Setting | Value | Source |
|---------|-------|--------|
| **SEED_ENABLED** | `true` | ConfigMap |
| **SEED_ADMIN_EMAIL** | `admin@murror.app` | ConfigMap |
| **SEED_ADMIN_PASSWORD** | (configured) | Kubernetes Secret |

### Default Admin Account

| Property | Value |
|----------|-------|
| **Email** | `admin@murror.app` |
| **Username** | `admin` |
| **Full Name** | System Administrator |
| **Roles** | `ADMIN` |
| **Password** | Stored in Kubernetes secret `auth-service` |

### Configuration Details

**Kubernetes ConfigMap** (`auth-service-config`):
```yaml
SEED_ENABLED: "true"
SEED_ADMIN_EMAIL: "admin@murror.app"
```

**Kubernetes Secret** (`auth-service`):
```yaml
SEED_ADMIN_PASSWORD: (base64-encoded, stored in Kubernetes secret)
```

**GitHub Environment Secrets** (murror-platform repo, `alpha` environment):
- `AUTH_SERVICE__SEED_ADMIN_PASSWORD` - Admin password used during deployment

### First-Time Login

After the service starts:

1. Navigate to the Auth Service login page
2. Use email: `admin@murror.app`
3. Password is available from:
   - Kubernetes secret: `kubectl get secret -n murror-platform auth-service -o jsonpath='{.data.SEED_ADMIN_PASSWORD}' | base64 -d`
   - GitHub `alpha` environment secrets (for CI/CD reference)

### Disabling Seeding

To prevent automatic seeding on subsequent deployments:

```bash
# Edit the ConfigMap
kubectl patch configmap auth-service-config -n murror-platform \
  -p '{"data":{"SEED_ENABLED":"false"}}'
```

Or modify the Helm values:
```yaml
seedEnabled: false
```

## CI/CD Pipeline

The Auth Service is deployed via GitHub Actions from the `murror-platform` repository.

### GitHub Environment: `alpha`

**Secrets**:
- `AUTH_SERVICE__DATABASE_URL` - PostgreSQL connection string
- `AUTH_SERVICE__JWT_SECRET` - JWT signing secret
- `AUTH_SERVICE__JWT_REFRESH_SECRET` - JWT refresh token secret
- `AUTH_SERVICE__RESEND_API_KEY` - Email service API key
- `AUTH_SERVICE__GOOGLE_CLIENT_SECRET` - Google OAuth secret

**Variables**:
- `AUTH_SERVICE__APP_URL` = `https://auth-alpha.ambercare.app`
- `AUTH_SERVICE__INGRESS_HOST` = `auth-alpha.ambercare.app`
- `AUTH_SERVICE__EMAIL_FROM` = `noreply@ambercare.app`
- `AUTH_SERVICE__EMAIL_FROM_NAME` = `AmberCare Alpha`
- `AUTH_SERVICE__GOOGLE_CLIENT_ID` = (configured)

### Deployment Workflow

1. Push to `dev` branch in murror-platform repository
2. `alpha-pipeline.yml` triggers semantic release
3. Docker image built and pushed to GHCR
4. Helm chart deployed to SG3 cluster

## Verification

### Check Deployment Status

```bash
# Switch to SG3 context
kubectl config use-context sg3

# Check pods
kubectl get pods -n murror-platform -l app.kubernetes.io/name=auth-service

# Check service
kubectl get svc -n murror-platform auth-service

# Check ingress
kubectl get ingress -n murror-platform auth-service

# Check TLS certificate
kubectl get certificate -n murror-platform
```

### Test Health Endpoint

```bash
# External
curl https://auth-alpha.ambercare.app/api/health

# Internal (from within cluster)
kubectl run curl-test --rm -it --image=curlimages/curl -- \
  curl http://auth-service.murror-platform.svc.cluster.local:3002/api/health
```

### Check Logs

```bash
kubectl logs -n murror-platform -l app.kubernetes.io/name=auth-service --tail=100 -f
```

### Database Connectivity

```bash
# Test database connection
kubectl exec -it postgresql-sg3-pgvector-2 -n postgres-db -- \
  psql -U murror_auth_service -d murror_auth_service -c "SELECT 1;"
```

## Features

- **JWT Authentication**: Access and refresh token support
- **OAuth 2.0**: Google OAuth integration
- **User Management**: Registration, login, password reset
- **Email Verification**: Via Resend email service
- **Role-Based Access**: User, Admin, Moderator roles
- **Workspace/Team**: Multi-tenant workspace support
- **Audit Logging**: Track authentication events

## Troubleshooting

### Pod Not Starting

1. Check pod events:
   ```bash
   kubectl describe pod -n murror-platform -l app.kubernetes.io/name=auth-service
   ```

2. Check logs:
   ```bash
   kubectl logs -n murror-platform -l app.kubernetes.io/name=auth-service --previous
   ```

3. Verify secrets are configured:
   ```bash
   kubectl get secret -n murror-platform
   ```

### Database Connection Issues

1. Verify database exists:
   ```bash
   kubectl exec -it postgresql-sg3-pgvector-2 -n postgres-db -- psql -U postgres -c "\l" | grep murror_auth
   ```

2. Test connectivity from pod:
   ```bash
   kubectl exec -it -n murror-platform <pod-name> -- \
     nc -zv postgresql-sg3-pgvector-rw.postgres-db.svc.cluster.local 5432
   ```

### TLS Certificate Issues

1. Check certificate status:
   ```bash
   kubectl describe certificate -n murror-platform
   ```

2. Check cert-manager logs:
   ```bash
   kubectl logs -n cert-manager -l app=cert-manager --tail=50
   ```

## Related Documentation

- [SG3 Services Overview](./SERVICES.md)
- [SG3 Cluster README](./README.md)
- [PostgreSQL Documentation](../../../database/postgresql/clusters/sg3/README.md)
- [TLS Certificates](../../../tls-certificates/README.md)

## Change Log

- **2025-01-22**: Added admin user seeding configuration
  - Configured SEED_ENABLED and SEED_ADMIN_EMAIL in ConfigMap
  - Added SEED_ADMIN_PASSWORD to Kubernetes secret
  - Created default admin account (admin@murror.app)
  - Updated GitHub alpha environment secrets for deployment

- **2025-01-14**: Initial deployment to SG3 cluster (Alpha environment)
  - Created murror_auth_service database
  - Configured GitHub alpha environment secrets/variables
  - Integrated with murror-platform CI/CD pipeline
