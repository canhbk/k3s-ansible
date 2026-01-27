# Kong Ingress Controller - SG3 Cluster

Kong Ingress Controller deployment for the SG3 (Singapore) production cluster.

## Cluster Information

- **Cluster**: sg3
- **Provider**: OVH
- **Region**: Singapore
- **Environment**: Production
- **Node Count**: 2 worker nodes
- **Kong Replicas**: 2 (HA mode)

## Domains

- **Kong Proxy**: https://kong.sg3.canhnv.com
- **Kong API**: https://api.sg3.canhnv.com
- **Kong Admin** (Internal): kong-admin.sg3.canhnv.com (protected with basic auth)

## Configuration

### Resource Allocation

**Kong Gateway**:
- Requests: 500m CPU, 1Gi Memory
- Limits: 2 CPU, 2Gi Memory
- Replicas: 2

**Kong Ingress Controller**:
- Requests: 200m CPU, 256Mi Memory
- Limits: 1 CPU, 1Gi Memory
- Replicas: 2

### High Availability

Kong is deployed in HA mode with:
- 2 gateway replicas
- 2 ingress controller replicas
- Pod anti-affinity for node distribution
- Topology spread constraints
- Pod disruption budget (maxUnavailable: 1)

### Networking

**Ingress**:
- Primary ingress via Traefik
- TLS certificates from cert-manager
- Cluster issuer: `canhnv-com-prod`

**Services**:
- `kong-kong-proxy`: ClusterIP (Port 80/443)
- `kong-kong-admin`: ClusterIP (Port 8001)
- `kong-kong-status`: ClusterIP (Port 8100) - Metrics

### Monitoring

**Prometheus**:
- ServiceMonitor for gateway metrics
- ServiceMonitor for ingress controller metrics
- Scrape interval: 30s

**Grafana**:
- Dashboard: "Kong API Gateway - SG3"
- Location: monitoring/clusters/sg3/kong-dashboard-configmap.yaml

**Alerts**:
- 8 alert rules configured
- Severities: Critical, Warning, Info
- Integration with AlertManager

## Deployment

### Prerequisites

Ensure the following are deployed on SG3:
- Traefik ingress controller
- cert-manager with `canhnv-com-prod` cluster issuer
- kube-prometheus-stack

### Deploy

```bash
# From repository root
cd apps/kong

# Deploy to SG3
./scripts/deploy.sh sg3

# Verify
kubectl config use-context sg3
kubectl get pods -n kong
kubectl get svc -n kong
kubectl get ingress -n kong
```

### Post-Deployment Verification

1. **Check pod status**:
```bash
kubectl get pods -n kong
# Expected: 4 pods running (2 gateway + 2 controller)
```

2. **Check services**:
```bash
kubectl get svc -n kong
# Expected: kong-kong-proxy, kong-kong-admin, kong-kong-status
```

3. **Test proxy**:
```bash
curl -I https://kong.sg3.canhnv.com
# Expected: HTTP/2 404 (no routes configured yet)
```

4. **Check Prometheus targets**:
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open http://localhost:9090/targets
# Search for "kong" - should see 2 targets (gateway + controller)
```

5. **Check Grafana dashboard**:
```bash
# Open https://grafana.sg3.k3s.canhnv.com
# Search for "Kong API Gateway - SG3"
```

## Operations

### View Logs

**Gateway logs**:
```bash
kubectl logs -n kong -l app.kubernetes.io/name=kong --tail=100 -f
```

**Controller logs**:
```bash
kubectl logs -n kong -l app.kubernetes.io/component=controller --tail=100 -f
```

### Check Health

**Gateway health**:
```bash
kubectl exec -it -n kong deploy/kong-kong -- kong health
```

**Admin API**:
```bash
kubectl port-forward -n kong svc/kong-kong-admin 8001:8001
curl http://localhost:8001/status
```

### Metrics

**View raw metrics**:
```bash
kubectl port-forward -n kong svc/kong-kong-status 8100:8100
curl http://localhost:8100/metrics
```

**Query via Prometheus**:
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open http://localhost:9090
# Query: kong_http_requests_total
```

### Scale

**Increase replicas**:
```bash
# Update values.yaml
# deployment.kong.replicaCount: 3

# Re-deploy
./scripts/deploy.sh sg3
```

**Or scale directly** (temporary):
```bash
kubectl scale deployment kong-kong -n kong --replicas=3
```

### Restart

**Rolling restart**:
```bash
kubectl rollout restart deployment/kong-kong -n kong
kubectl rollout restart deployment/kong-kong-controller -n kong
```

### Upgrade

1. Update version in `base/values-base.yaml`
2. Run deployment script:
```bash
./scripts/deploy.sh sg3
```

## Routing Example

### Deploy Test Service

```bash
# Create httpbin deployment
kubectl create deployment httpbin --image=kennethreitz/httpbin -n default
kubectl expose deployment httpbin --port=80 -n default
```

### Create Kong Ingress

```bash
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
```

### Test

```bash
curl https://kong.sg3.canhnv.com/httpbin/get
```

## Plugin Examples

### Rate Limiting

```bash
kubectl apply -f - <<EOF
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: rate-limit-5-per-min
  namespace: default
config:
  minute: 5
  policy: local
plugin: rate-limiting
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: httpbin
  namespace: default
  annotations:
    konghq.com/plugins: rate-limit-5-per-min
spec:
  # ... (same as above)
EOF
```

Test rate limiting:
```bash
for i in {1..10}; do curl -I https://kong.sg3.canhnv.com/httpbin/get; done
# Should see 429 after 5 requests
```

### CORS

```bash
kubectl apply -f - <<EOF
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: cors
  namespace: default
config:
  origins:
  - "*"
  methods:
  - GET
  - POST
  - PUT
  - DELETE
  headers:
  - Authorization
  - Content-Type
  credentials: true
  max_age: 3600
plugin: cors
EOF

# Apply to ingress
kubectl annotate ingress httpbin -n default konghq.com/plugins=cors --overwrite
```

## Troubleshooting

### Pods Not Ready

**Check pod status**:
```bash
kubectl describe pod -n kong <pod-name>
```

**Common issues**:
- Resource constraints (check node capacity)
- Image pull errors (check registry)
- Failed probes (check logs)

### Configuration Not Applied

**Check controller logs**:
```bash
kubectl logs -n kong -l app.kubernetes.io/component=controller --tail=50
```

**Look for**:
- Translation errors
- Config push failures
- CRD validation errors

**Verify config was pushed**:
```bash
kubectl port-forward -n kong svc/kong-kong-admin 8001:8001
curl http://localhost:8001/config | jq .
```

### High Latency

**Check metrics**:
```bash
# View Grafana dashboard
open https://grafana.sg3.k3s.canhnv.com

# Or query Prometheus directly
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Query: histogram_quantile(0.95, sum(rate(kong_request_latency_ms_bucket[5m])) by (le, service))
```

**Investigate**:
1. Kong processing latency (check plugins)
2. Upstream latency (check backend services)
3. Network latency (check node network)

### Upstream Unhealthy

**Check upstream health**:
```bash
kubectl port-forward -n kong svc/kong-kong-admin 8001:8001
curl http://localhost:8001/upstreams
curl http://localhost:8001/upstreams/<upstream-name>/health
```

**Check backend service**:
```bash
kubectl get endpoints -n <namespace> <service-name>
kubectl describe service -n <namespace> <service-name>
```

## Monitoring Queries

### Prometheus Queries

**Request rate**:
```promql
sum(rate(kong_http_requests_total{namespace="kong"}[5m])) by (service)
```

**Error rate**:
```promql
sum(rate(kong_http_requests_total{namespace="kong", code=~"5.."}[5m]))
/
sum(rate(kong_http_requests_total{namespace="kong"}[5m]))
```

**P95 latency**:
```promql
histogram_quantile(0.95,
  sum(rate(kong_request_latency_ms_bucket{namespace="kong"}[5m])) by (le, service)
)
```

**Upstream health**:
```promql
kong_upstream_target_health{namespace="kong"}
```

**CPU usage**:
```promql
100 * (
  sum(rate(container_cpu_usage_seconds_total{namespace="kong", pod=~"kong-.*"}[5m]))
  /
  sum(container_spec_cpu_quota{namespace="kong", pod=~"kong-.*"} / 100000)
)
```

## Files

- `values.yaml` - SG3-specific Helm values
- `prometheus-plugin.yaml` - Prometheus plugin configuration
- `servicemonitor.yaml` - Prometheus ServiceMonitor definitions
- `prometheus-alerts.yaml` - Alert rules
- `ingress.yaml` - Ingress resources

## Related Documentation

- [Kong Overview](../../README.md)
- [Deployment Guide](../../../../docs/services/kong/DEPLOYMENT.md)
- [Monitoring Guide](../../../../docs/services/kong/MONITORING.md)
- [Operations Runbook](../../../../docs/services/kong/OPERATIONS.md)
