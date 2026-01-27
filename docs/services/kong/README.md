# Kong Ingress Controller Documentation

Welcome to the Kong Ingress Controller documentation for the k3s-ansible infrastructure.

## Overview

Kong Ingress Controller (KIC) provides API gateway capabilities for Kubernetes clusters, offering advanced traffic management, security, and observability features.

## Documentation Structure

- **[Deployment Guide](./DEPLOYMENT.md)** - Complete deployment instructions
- **[Monitoring Guide](./MONITORING.md)** - Metrics, dashboards, and alerting
- **[Operations Runbook](./OPERATIONS.md)** - Day-to-day operations and troubleshooting

## Quick Links

### Configuration Files

- **Base Configuration**: `/apps/kong/base/`
- **SG3 Cluster**: `/apps/kong/clusters/sg3/`
- **Deployment Script**: `/apps/kong/scripts/deploy.sh`
- **Grafana Dashboard**: `/monitoring/clusters/sg3/kong-dashboard-configmap.yaml`

### Application README

- **Main Kong README**: `/apps/kong/README.md` - Comprehensive guide with architecture, examples, and usage

## Cluster Deployments

| Cluster | Status | Domain | Documentation |
|---------|--------|--------|---------------|
| sg3     | ✅ Active | kong.sg3.canhnv.com | [SG3 README](/apps/kong/clusters/sg3/README.md) |
| dev     | 🚧 Planned | kong.dev.canhnv.com | - |
| vn      | 🚧 Planned | kong.vn.canhnv.com | - |
| us      | 🚧 Planned | kong.us.canhnv.com | - |

## Key Features

### Traffic Management
- Advanced request routing and load balancing
- Request/response transformation
- Traffic splitting and canary deployments
- Circuit breaking and retries

### Security
- Authentication (API keys, JWT, OAuth2, LDAP)
- Authorization and RBAC
- Rate limiting and quotas
- IP restriction and bot detection
- Request validation

### Observability
- Comprehensive Prometheus metrics
- Real-time Grafana dashboards
- Request/response logging
- Distributed tracing support

### Developer Experience
- Kubernetes-native configuration (CRDs)
- Declarative API management
- Plugin ecosystem (50+ plugins)
- Multi-protocol support (HTTP, HTTPS, gRPC, WebSocket)

## Architecture

Kong consists of two main components:

1. **Kong Gateway** (Data Plane)
   - Processes API requests
   - Executes plugins
   - Routes to upstream services
   - Exposes metrics

2. **Kong Ingress Controller** (Control Plane)
   - Watches Kubernetes resources
   - Translates to Kong configuration
   - Pushes config to Kong Gateway
   - Manages CRDs

## Common Use Cases

### 1. API Gateway for Microservices

Route external traffic to internal services with authentication and rate limiting:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-api
  annotations:
    konghq.com/plugins: rate-limit,api-key-auth
spec:
  ingressClassName: kong
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /users
        backend:
          service:
            name: user-service
            port: 80
```

### 2. Service Mesh Gateway

Provide ingress gateway functionality for a service mesh:

```yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: circuit-breaker
config:
  max_failures: 5
  timeout: 10
  recovery_time: 30
plugin: circuit-breaker
```

### 3. Multi-Tenant API Platform

Isolate tenants with separate authentication and rate limiting:

```yaml
apiVersion: configuration.konghq.com/v1
kind: KongConsumer
metadata:
  name: tenant-a
username: tenant-a
---
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: tenant-a-rate-limit
config:
  minute: 1000
  policy: local
plugin: rate-limiting
```

## Getting Started

### 1. Prerequisites

Ensure the following are available:
- Kubernetes cluster (K3s)
- Helm 3.x
- kubectl configured
- Traefik ingress controller
- cert-manager
- Prometheus Operator

### 2. Deploy Kong

```bash
cd /apps/kong
./scripts/deploy.sh sg3
```

### 3. Verify Installation

```bash
kubectl get pods -n kong
kubectl get svc -n kong
```

### 4. Create Your First Route

```bash
# Deploy test service
kubectl create deployment echo --image=gcr.io/kubernetes-e2e-test-images/echoserver:2.3
kubectl expose deployment echo --port=8080

# Create ingress
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: echo
spec:
  ingressClassName: kong
  rules:
  - host: kong.sg3.canhnv.com
    http:
      paths:
      - path: /echo
        pathType: Prefix
        backend:
          service:
            name: echo
            port:
              number: 8080
EOF

# Test
curl https://kong.sg3.canhnv.com/echo
```

### 5. Add Rate Limiting

```bash
kubectl apply -f - <<EOF
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: rate-limit-example
config:
  minute: 10
  policy: local
plugin: rate-limiting
EOF

# Apply to ingress
kubectl annotate ingress echo konghq.com/plugins=rate-limit-example
```

## Support and Resources

### Internal Documentation
- [Deployment Guide](./DEPLOYMENT.md) - Step-by-step deployment
- [Monitoring Guide](./MONITORING.md) - Metrics and dashboards
- [Operations Runbook](./OPERATIONS.md) - Troubleshooting

### External Resources
- [Kong Gateway Docs](https://docs.konghq.com/gateway/latest/)
- [Kong Ingress Controller Docs](https://docs.konghq.com/kubernetes-ingress-controller/latest/)
- [Kong Plugin Hub](https://docs.konghq.com/hub/)
- [Kong Community Forum](https://discuss.konghq.com/)

### Getting Help

1. Check the [Operations Runbook](./OPERATIONS.md) for common issues
2. Review Kong logs: `kubectl logs -n kong -l app.kubernetes.io/name=kong`
3. Check Grafana dashboard for metrics and alerts
4. Review Prometheus alerts for active issues

## Next Steps

- [Deploy Kong to a cluster](./DEPLOYMENT.md)
- [Set up monitoring and dashboards](./MONITORING.md)
- [Learn common operations](./OPERATIONS.md)
- [Explore plugin examples](/apps/kong/README.md#plugin-examples)
