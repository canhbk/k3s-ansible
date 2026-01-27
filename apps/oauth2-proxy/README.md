# oauth2-proxy

Centralized OAuth2 authentication proxy for K3s clusters. Integrates with Traefik ForwardAuth middleware to protect services.

## Overview

oauth2-proxy is a reverse proxy that provides authentication using OAuth2 providers (Google, GitHub, OIDC) to validate accounts.

## Cluster Deployments

| Cluster | Status | URL |
|---------|--------|-----|
| sg3 | Deployed | https://oauth2-proxy.sg3.canhnv.com |

## Quick Start

### Prerequisites

- Traefik ingress controller
- cert-manager with ClusterIssuer
- OAuth provider credentials (Google, GitHub, etc.)

### Deploy

```bash
# Create secrets
./scripts/create-secrets.sh <cluster>

# Deploy
./scripts/deploy.sh <cluster>
```

### Protect a Service

Add this annotation to any Ingress:

```yaml
annotations:
  traefik.ingress.kubernetes.io/router.middlewares: oauth2-proxy-oauth2-proxy-chain@kubernetescrd
```

## Documentation

- [Deployment Guide](../../docs/services/oauth2-proxy/DEPLOYMENT.md)
- [Protecting Services](../../docs/services/oauth2-proxy/PROTECTING_SERVICES.md)
- [Cluster: SG3](./clusters/sg3/README.md)

## Architecture

```
User Request → Traefik → ForwardAuth Middleware → oauth2-proxy
                                │
                                ├─ Authenticated → Backend Service
                                └─ Not Authenticated → OAuth Provider
```

## Components

| Component | Purpose |
|-----------|---------|
| Deployment | Authentication proxy (2 replicas) |
| Service | ClusterIP for internal access |
| Ingress | OAuth callback handling |
| ForwardAuth Middleware | Traefik integration |
| ServiceMonitor | Prometheus metrics |
