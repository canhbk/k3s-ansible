# oauth2-proxy Service Documentation

## Overview

oauth2-proxy is a reverse proxy that provides authentication using OAuth2 providers (Google, GitHub, OIDC) to validate accounts. It integrates with Traefik's ForwardAuth middleware to protect services.

## Architecture

```
User Request → Traefik → ForwardAuth Middleware → oauth2-proxy
                                │
                                ├─ Authenticated → Backend Service
                                └─ Not Authenticated → OAuth Provider
```

### Authentication Flow

1. User requests protected resource
2. Traefik forwards request to oauth2-proxy via ForwardAuth
3. oauth2-proxy checks for valid session cookie
4. If authenticated: Returns 200 + user headers
5. If not authenticated: Redirects to OAuth provider
6. User authenticates with provider
7. oauth2-proxy creates session, sets cookie
8. User redirected to original URL

## Cluster Deployments

| Cluster | Status | URL |
|---------|--------|-----|
| sg3 | Deployed | https://oauth2-proxy.sg3.canhnv.com |

## Quick Reference

### Protect a Service

```yaml
annotations:
  traefik.ingress.kubernetes.io/router.middlewares: oauth2-proxy-oauth2-proxy-chain@kubernetescrd
```

### Check Status

```bash
# Health check
curl https://oauth2-proxy.sg3.canhnv.com/ping

# User info (requires session)
curl https://oauth2-proxy.sg3.canhnv.com/oauth2/userinfo
```

## Documentation

- [Deployment Guide](./DEPLOYMENT.md)
- [Protecting Services](./PROTECTING_SERVICES.md)

## Related

- [Traefik ForwardAuth](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)
- [oauth2-proxy Docs](https://oauth2-proxy.github.io/oauth2-proxy/)
