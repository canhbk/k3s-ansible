# Kong Ingress Controller

Kong Ingress Controller (KIC) is an open-source Kubernetes Ingress Controller that manages external access to services in a Kubernetes cluster using Kong Gateway as the data plane.

## Overview

Kong Gateway acts as a high-performance API gateway and service mesh that provides:

- **Traffic Management**: Advanced routing, load balancing, and request/response transformations
- **Security**: Authentication, authorization, rate limiting, and API key management
- **Observability**: Comprehensive metrics, logging, and tracing
- **Plugin Ecosystem**: Extensible architecture with 50+ plugins for various use cases

This deployment uses:
- **Kong Gateway**: Database-less (DB-less) mode for stateless operation
- **Kong Ingress Controller**: Kubernetes-native configuration via CRDs
- **Prometheus Integration**: Full metrics exposure and alerting
- **Grafana Dashboards**: Real-time monitoring and visualization

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      External Traffic                        │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │   Traefik Ingress    │
                  │  (TLS Termination)   │
                  └──────────┬───────────┘
                             │
                             ▼
           ┌─────────────────────────────────────┐
           │      Kong Gateway Proxy             │
           │   (ClusterIP Service - Port 80)     │
           │                                     │
           │  • Request Routing                  │
           │  • Rate Limiting                    │
           │  • Authentication                   │
           │  • Request/Response Transform       │
           │  • Metrics Collection               │
           └─────────┬───────────────────────────┘
                     │
         ┌───────────┴────────────┐
         │                        │
         ▼                        ▼
┌─────────────────┐      ┌─────────────────┐
│   Backend       │      │   Backend       │
│   Service 1     │      │   Service 2     │
└─────────────────┘      └─────────────────┘

Control Plane:
┌──────────────────────────────────────────┐
│   Kong Ingress Controller                │
│                                          │
│  • Watches Kubernetes Resources          │
│  • Translates to Kong Configuration      │
│  • Pushes to Kong Gateway                │
└──────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│   Kong Admin API (Internal Only)         │
│   ClusterIP Service - Port 8001          │
└──────────────────────────────────────────┘

Monitoring:
┌──────────────────────────────────────────┐
│   Kong Status API (Metrics)              │
│   ClusterIP Service - Port 8100          │
│   /metrics endpoint                      │
└──────────┬───────────────────────────────┘
           │
           ▼
    ┌──────────────┐
    │  Prometheus  │
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │   Grafana    │
    └──────────────┘
```

## Supported Clusters

| Cluster | Status | Domain | HA Mode | Notes |
|---------|--------|--------|---------|-------|
| sg3     | ✅ Ready | kong.sg3.canhnv.com | Yes (2 replicas) | Primary deployment |
| dev     | 🚧 Planned | kong.dev.canhnv.com | No (1 replica) | Development testing |
| vn      | 🚧 Planned | kong.vn.canhnv.com | Yes (2 replicas) | Production |
| us      | 🚧 Planned | kong.us.canhnv.com | Yes (2 replicas) | Production |

## Quick Start

### Prerequisites

1. Helm 3.x installed
2. kubectl configured with cluster access
3. Traefik ingress controller deployed
4. cert-manager for TLS certificates
5. Prometheus Operator for monitoring

### Deploy to SG3 Cluster

```bash
# From the repository root
cd apps/kong

# Deploy Kong to SG3
./scripts/deploy.sh sg3

# Verify deployment
kubectl get pods -n kong
kubectl get svc -n kong
kubectl get ingress -n kong
```

### Access Kong

**Kong Proxy (via Traefik)**:
```bash
# External access
curl https://kong.sg3.canhnv.com

# Or use the API domain
curl https://api.sg3.canhnv.com
```

**Kong Admin API (Internal)**:
```bash
# Port-forward to access admin API
kubectl port-forward -n kong svc/kong-kong-admin 8001:8001

# Test admin API
curl http://localhost:8001/status
```

**Prometheus Metrics**:
```bash
# Port-forward to access metrics
kubectl port-forward -n kong svc/kong-kong-status 8100:8100

# Fetch metrics
curl http://localhost:8100/metrics
```

## Configuration Structure

```
apps/kong/
├── base/
│   ├── namespace.yaml              # Kong namespace definition
│   └── values-base.yaml            # Base Helm values (shared)
├── clusters/
│   └── sg3/
│       ├── values.yaml             # SG3-specific Helm values
│       ├── prometheus-plugin.yaml  # Prometheus plugin config
│       ├── servicemonitor.yaml     # Prometheus ServiceMonitor
│       ├── prometheus-alerts.yaml  # Alert rules
│       ├── ingress.yaml            # Ingress resources
│       └── README.md               # SG3-specific docs
├── scripts/
│   └── deploy.sh                   # Deployment automation
└── README.md                       # This file
```

## Configuration Options

### Base Values (`base/values-base.yaml`)

Shared configuration across all clusters:
- Kong Gateway version and image
- Resource limits (CPU/Memory)
- Security context (non-root user)
- Proxy configuration (timeouts, keepalive)
- Admin API settings
- Pod disruption budget
- Update strategy

### Cluster-Specific Values (`clusters/*/values.yaml`)

Override base values for each cluster:
- Replica count (HA mode)
- Cluster-specific labels
- Resource adjustments
- Environment variables
- Node affinity/tolerations

### Example: Enabling a New Cluster

1. Create cluster directory:
```bash
mkdir -p apps/kong/clusters/vn
```

2. Create `values.yaml`:
```yaml
# VN cluster values
global:
  additionalLabels:
    cluster: vn
    environment: production

deployment:
  kong:
    replicaCount: 2  # HA

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2
    memory: 2Gi
```

3. Copy monitoring configs:
```bash
cp clusters/sg3/prometheus-plugin.yaml clusters/vn/
cp clusters/sg3/servicemonitor.yaml clusters/vn/
cp clusters/sg3/prometheus-alerts.yaml clusters/vn/
# Update cluster labels in each file
```

4. Create ingress:
```yaml
# clusters/vn/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kong-proxy
  namespace: kong
spec:
  ingressClassName: traefik
  rules:
    - host: kong.vn.canhnv.com
      # ...
```

5. Deploy:
```bash
./scripts/deploy.sh vn
```

## Monitoring

### Metrics

Kong exposes Prometheus metrics on the status API (port 8100):

**Request Metrics**:
- `kong_http_requests_total`: Total HTTP requests by service, route, status code
- `kong_request_latency_ms`: Request latency histogram (full request)
- `kong_kong_latency_ms`: Kong processing latency (routing + plugins)
- `kong_upstream_latency_ms`: Upstream service latency

**Bandwidth Metrics**:
- `kong_bandwidth_bytes`: Ingress/egress bandwidth by service

**Upstream Health**:
- `kong_upstream_target_health`: Health status of upstream targets (0=unhealthy, 1=healthy)

**Ingress Controller Metrics**:
- `ingress_controller_configuration_push_count`: Config push success/failure
- `ingress_controller_translation_count`: Time to translate K8s resources to Kong config

### Grafana Dashboard

A comprehensive Grafana dashboard is included:

**Location**: `monitoring/clusters/sg3/kong-dashboard-configmap.yaml`

**Panels**:
1. Overview: Instances up, request rate, status codes
2. Latency: P50/P95/P99 percentiles by service
3. Bandwidth: Ingress/egress by service
4. Upstream Health: Target health status table
5. Resources: CPU and memory usage
6. Ingress Controller: Config push rate and status

**Access**:
```bash
# Open Grafana
open https://grafana.sg3.k3s.canhnv.com

# Search for: "Kong API Gateway - SG3"
```

### Alerts

Prometheus alerts are configured for:

**Critical**:
- Kong Gateway down (all instances)
- Very high 5xx error rate (>5%)
- All upstream targets unhealthy

**Warning**:
- Kong Gateway instance down
- High request latency (P95 > 500ms)
- High 4xx error rate (>5%)
- High 5xx error rate (>1%)
- High CPU/Memory usage (>85%)
- Upstream target unhealthy
- Ingress Controller config push failures

**Info**:
- High bandwidth throughput

## Operations

### Common Tasks

**Check Kong Health**:
```bash
kubectl exec -it -n kong deploy/kong-kong -- kong health
```

**View Kong Configuration**:
```bash
kubectl port-forward -n kong svc/kong-kong-admin 8001:8001
curl http://localhost:8001/config
```

**Test Routing**:
```bash
# Create a test service
kubectl create deployment httpbin --image=kennethreitz/httpbin -n default
kubectl expose deployment httpbin --port=80 -n default

# Create Kong Ingress
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: httpbin
  namespace: default
  annotations:
    konghq.com/strip-path: "true"
spec:
  ingressClassName: kong
  rules:
  - host: kong.sg3.canhnv.com
    http:
      paths:
      - path: /httpbin
        pathType: Prefix
        backend:
          service:
            name: httpbin
            port:
              number: 80
EOF

# Test
curl https://kong.sg3.canhnv.com/httpbin/get
```

**Scale Kong**:
```bash
# Scale gateway pods
kubectl scale deployment kong-kong -n kong --replicas=3

# Scale ingress controller
kubectl scale deployment kong-kong-controller -n kong --replicas=3
```

**View Logs**:
```bash
# Kong Gateway logs
kubectl logs -n kong -l app.kubernetes.io/name=kong --tail=100 -f

# Ingress Controller logs
kubectl logs -n kong -l app.kubernetes.io/component=controller --tail=100 -f
```

**Restart Kong**:
```bash
# Restart gateway
kubectl rollout restart deployment/kong-kong -n kong

# Restart ingress controller
kubectl rollout restart deployment/kong-kong-controller -n kong
```

### Upgrade Kong

1. Update version in `base/values-base.yaml`:
```yaml
image:
  repository: kong
  tag: "3.8.0"  # Update version
```

2. Deploy upgrade:
```bash
./scripts/deploy.sh sg3
```

3. Verify:
```bash
kubectl get pods -n kong -w
```

### Uninstall

```bash
# Uninstall Kong Helm release
helm uninstall kong -n kong

# Delete namespace (optional)
kubectl delete namespace kong

# Delete monitoring resources
kubectl delete -f monitoring/clusters/sg3/kong-dashboard-configmap.yaml
kubectl delete prometheusrule kong-alerts -n monitoring
```

## Troubleshooting

### Pods Not Starting

**Check events**:
```bash
kubectl describe pod -n kong <pod-name>
```

**Common issues**:
- Insufficient resources (check node capacity)
- Image pull errors (check registry access)
- Failed health checks (check Kong logs)

### High Latency

**Check metrics**:
```bash
kubectl port-forward -n kong svc/kong-kong-status 8100:8100
curl http://localhost:8100/metrics | grep latency
```

**Investigate**:
- Upstream service latency (check backend services)
- Kong processing latency (check plugins)
- Network latency (check node network)

### Configuration Not Applied

**Check Ingress Controller logs**:
```bash
kubectl logs -n kong -l app.kubernetes.io/component=controller --tail=100
```

**Verify CRDs**:
```bash
kubectl get crd | grep kong
```

**Check config push status**:
```bash
# Should show recent successful pushes
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Query: ingress_controller_configuration_push_count
```

### Upstream Health Issues

**Check target health**:
```bash
kubectl port-forward -n kong svc/kong-kong-admin 8001:8001
curl http://localhost:8001/upstreams
curl http://localhost:8001/upstreams/<upstream-name>/health
```

**Common causes**:
- Backend service not running
- Service endpoints not ready
- Network policy blocking traffic
- Health check configuration mismatch

## Kong Resources (CRDs)

Kong extends Kubernetes with custom resources:

**KongPlugin**: Configure plugins for routes/services
```yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: rate-limit
config:
  minute: 100
  policy: local
plugin: rate-limiting
```

**KongClusterPlugin**: Global plugins (cluster-wide)
```yaml
apiVersion: configuration.konghq.com/v1
kind: KongClusterPlugin
metadata:
  name: prometheus
  labels:
    global: "true"
spec:
  plugin: prometheus
```

**KongIngress**: Advanced routing configuration
```yaml
apiVersion: configuration.konghq.com/v1
kind: KongIngress
metadata:
  name: sample-ingress
route:
  methods:
  - GET
  - POST
  strip_path: true
upstream:
  algorithm: round-robin
  hash_on: ip
```

**KongConsumer**: API consumers with credentials
```yaml
apiVersion: configuration.konghq.com/v1
kind: KongConsumer
metadata:
  name: consumer1
username: consumer1
credentials:
- key-auth-credential
```

## Plugin Examples

### Rate Limiting

```yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: rate-limit-plugin
config:
  minute: 100
  hour: 1000
  policy: local
plugin: rate-limiting
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-api
  annotations:
    konghq.com/plugins: rate-limit-plugin
spec:
  # ...
```

### CORS

```yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: cors-plugin
config:
  origins:
  - https://example.com
  methods:
  - GET
  - POST
  headers:
  - Authorization
  - Content-Type
  exposed_headers:
  - X-Custom-Header
  credentials: true
  max_age: 3600
plugin: cors
```

### Request/Response Transformation

```yaml
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: transform-plugin
config:
  add:
    headers:
    - "X-Custom-Header: value"
  remove:
    headers:
    - "X-Internal-Header"
plugin: request-transformer
```

## Security Best Practices

1. **Admin API Protection**:
   - Never expose admin API externally
   - Use port-forwarding for administrative access
   - Consider adding basic auth middleware if exposed via ingress

2. **Plugin Configuration**:
   - Store sensitive plugin configs in Kubernetes Secrets
   - Reference secrets in KongPlugin resources

3. **Network Policies**:
   - Restrict Kong namespace traffic
   - Allow only necessary ingress/egress

4. **RBAC**:
   - Use separate service accounts for gateway and controller
   - Apply least-privilege principle

5. **TLS**:
   - Always use TLS for external traffic
   - Let Traefik handle TLS termination
   - Use cert-manager for certificate automation

## Resources

- [Kong Gateway Documentation](https://docs.konghq.com/gateway/latest/)
- [Kong Ingress Controller Documentation](https://docs.konghq.com/kubernetes-ingress-controller/latest/)
- [Kong Plugin Hub](https://docs.konghq.com/hub/)
- [Kong Helm Chart](https://github.com/Kong/charts)

## See Also

- [Deployment Guide](../../docs/services/kong/DEPLOYMENT.md)
- [Monitoring Guide](../../docs/services/kong/MONITORING.md)
- [Operations Runbook](../../docs/services/kong/OPERATIONS.md)
- [SG3 Cluster Config](./clusters/sg3/README.md)
