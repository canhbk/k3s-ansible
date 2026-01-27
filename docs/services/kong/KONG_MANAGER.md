# Kong Manager OSS

## Overview

Kong Manager is the official GUI for Kong Gateway. In our DB-less deployment, Kong Manager operates in **read-only mode**, allowing you to view but not modify configuration.

## Access

- **URL**: https://kong-manager.sg3.canhnv.com
- **Authentication**: Basic Auth
  - Username: `admin`
  - Password: `KongAdmin2026!`

## Features in DB-less Mode

### Available (Read-Only)
- View all Routes
- View all Services
- View all Plugins
- View all Consumers
- View all Upstreams
- View Gateway status and health

### Not Available (Requires Database)
- Create/Update/Delete Routes
- Create/Update/Delete Services
- Configure Plugins via GUI
- Manage Consumers via GUI

## Making Configuration Changes

In DB-less mode, all configuration changes must be made through Kubernetes CRDs:

```bash
# Example: Create a KongPlugin
kubectl apply -f - <<EOF
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: rate-limit
  namespace: default
config:
  minute: 100
plugin: rate-limiting
EOF
```

## Clusters

| Cluster | URL | Status |
|---------|-----|--------|
| SG3 | https://kong-manager.sg3.canhnv.com | Active |

## Troubleshooting

### Manager Not Loading
1. Check pod status: `kubectl get pods -n kong`
2. Verify service: `kubectl get svc -n kong | grep manager`
3. Check ingress: `kubectl get ingress -n kong kong-manager`
4. View logs: `kubectl logs -n kong -l app.kubernetes.io/name=kong`

### Cannot Access from Remote
Ensure `admin_gui_listen` is bound to `0.0.0.0` not `127.0.0.1`.

### 401 Unauthorized
Check basic auth credentials in the `kong-manager-basic-auth` secret.

## Security Notes

- Kong Manager is protected by basic authentication via Traefik middleware
- Access is only available through HTTPS with TLS certificate from cert-manager
- In DB-less mode, Kong Manager is read-only by design, reducing security risks
- For production changes, always use GitOps workflow with Kubernetes CRDs

## Related Documentation

- [Kong Admin API](./ADMIN_API.md) - Admin API access for programmatic operations
- [Kong Configuration](../../clusters/sg3/README.md) - SG3 cluster configuration
- [Security Guidelines](../../SECURITY_GUIDELINES.md) - Authentication and authorization
