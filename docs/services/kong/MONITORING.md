# Kong Ingress Controller - Monitoring Guide

This guide covers monitoring Kong Ingress Controller using Prometheus and Grafana.

## Table of Contents

- [Overview](#overview)
- [Metrics Architecture](#metrics-architecture)
- [Available Metrics](#available-metrics)
- [Prometheus Configuration](#prometheus-configuration)
- [Grafana Dashboards](#grafana-dashboards)
- [Alerting](#alerting)
- [Common Queries](#common-queries)
- [Troubleshooting](#troubleshooting)

## Overview

Kong provides comprehensive observability through:

1. **Prometheus Metrics**: Real-time metrics from Kong Gateway and Ingress Controller
2. **Grafana Dashboards**: Visual representation of metrics
3. **Prometheus Alerts**: Automated alerting on critical conditions
4. **Access Logs**: Structured logging for request auditing

## Metrics Architecture

```
┌─────────────────────────────────────────────────────┐
│              Kong Gateway Pods                      │
│                                                     │
│  ┌──────────────────┐    ┌──────────────────┐     │
│  │  Kong Gateway    │    │  Ingress         │     │
│  │                  │    │  Controller      │     │
│  │  Port 8100       │    │  Port 10254      │     │
│  │  /metrics        │    │  /metrics        │     │
│  └────────┬─────────┘    └────────┬─────────┘     │
│           │                       │                │
└───────────┼───────────────────────┼────────────────┘
            │                       │
            │                       │
     ┌──────▼───────────────────────▼──────┐
     │      ServiceMonitor (CRD)           │
     │  • kong-gateway                     │
     │  • kong-ingress-controller          │
     └──────────────┬──────────────────────┘
                    │
                    ▼
     ┌──────────────────────────────┐
     │    Prometheus Operator        │
     │  • Discovers ServiceMonitors  │
     │  • Scrapes metrics (30s)      │
     │  • Stores time-series data    │
     │  • Evaluates alert rules      │
     └──────────┬───────────────────┘
                │
       ┌────────┴─────────┐
       │                  │
       ▼                  ▼
┌────────────┐    ┌──────────────┐
│  Grafana   │    │ AlertManager │
│ Dashboards │    │   Alerts     │
└────────────┘    └──────────────┘
```

## Available Metrics

### Kong Gateway Metrics

#### Request Metrics

| Metric | Type | Description | Labels |
|--------|------|-------------|--------|
| `kong_http_requests_total` | Counter | Total HTTP requests | service, route, code, source, consumer |
| `kong_request_latency_ms` | Histogram | Full request latency (ms) | service, route |
| `kong_kong_latency_ms` | Histogram | Kong processing latency (ms) | service, route |
| `kong_upstream_latency_ms` | Histogram | Upstream service latency (ms) | service, route |

**Example**:
```promql
# Request rate by service
rate(kong_http_requests_total[5m])

# P95 latency
histogram_quantile(0.95, sum(rate(kong_request_latency_ms_bucket[5m])) by (le))
```

#### Bandwidth Metrics

| Metric | Type | Description | Labels |
|--------|------|-------------|--------|
| `kong_bandwidth_bytes` | Counter | Total bandwidth (bytes) | service, route, direction (ingress/egress) |

**Example**:
```promql
# Bandwidth by service (bytes/sec)
rate(kong_bandwidth_bytes{direction="egress"}[5m])
```

#### Upstream Health Metrics

| Metric | Type | Description | Labels |
|--------|------|-------------|--------|
| `kong_upstream_target_health` | Gauge | Upstream target health (0=unhealthy, 1=healthy) | upstream, target, state |

**Example**:
```promql
# Number of unhealthy targets
count(kong_upstream_target_health{state="unhealthy"} == 1) by (upstream)
```

#### Dataplane Metrics

| Metric | Type | Description | Labels |
|--------|------|-------------|--------|
| `kong_dataplane_last_seen` | Gauge | Timestamp of last dataplane seen | node_id |
| `kong_nginx_connections_total` | Gauge | Total nginx connections | state (reading/writing/waiting) |
| `kong_memory_lua_shared_dict_bytes` | Gauge | Shared dict memory usage | shared_dict |

### Kong Ingress Controller Metrics

#### Configuration Metrics

| Metric | Type | Description | Labels |
|--------|------|-------------|--------|
| `ingress_controller_configuration_push_count` | Counter | Config push attempts | success (true/false) |
| `ingress_controller_configuration_push_duration_milliseconds` | Histogram | Config push duration (ms) | success |
| `ingress_controller_translation_count` | Histogram | Translation duration (ms) | success |

**Example**:
```promql
# Config push success rate
sum(rate(ingress_controller_configuration_push_count{success="true"}[5m]))
/
sum(rate(ingress_controller_configuration_push_count[5m]))
```

#### Resource Metrics

| Metric | Type | Description | Labels |
|--------|------|-------------|--------|
| `controller_runtime_reconcile_total` | Counter | Reconcile operations | controller, result |
| `controller_runtime_reconcile_time_seconds` | Histogram | Reconcile duration (seconds) | controller |

## Prometheus Configuration

### ServiceMonitor

Kong uses ServiceMonitors for Prometheus discovery:

**Gateway ServiceMonitor** (`apps/kong/clusters/sg3/servicemonitor.yaml`):
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kong-gateway
  namespace: kong
  labels:
    prometheus: kube-prometheus-stack
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: kong
  endpoints:
    - port: status
      path: /metrics
      interval: 30s
```

**Controller ServiceMonitor**:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kong-ingress-controller
  namespace: kong
spec:
  selector:
    matchLabels:
      app.kubernetes.io/component: controller
  endpoints:
    - port: cmetrics
      path: /metrics
      interval: 30s
```

### Prometheus Plugin

Kong exposes metrics via the Prometheus plugin:

```yaml
apiVersion: configuration.konghq.com/v1
kind: KongClusterPlugin
metadata:
  name: prometheus
spec:
  plugin: prometheus
  config:
    status_code_metrics: true
    latency_metrics: true
    bandwidth_metrics: true
    upstream_health_metrics: true
    per_consumer: false  # Reduce cardinality
```

### Verifying Prometheus Scraping

**Check targets**:
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open http://localhost:9090/targets
# Search for "kong"
```

**Expected Targets**:
- `monitoring/kong-gateway/0` (2/2 up)
- `monitoring/kong-ingress-controller/0` (2/2 up)

**Test metric availability**:
```bash
# In Prometheus UI, execute query:
kong_http_requests_total
```

## Grafana Dashboards

### Main Dashboard: "Kong API Gateway - SG3"

Location: `monitoring/clusters/sg3/kong-dashboard-configmap.yaml`

#### Dashboard Panels

**Overview Row**:
1. **Kong Instances Up** (Stat)
   - Shows number of healthy Kong instances
   - Thresholds: red < 1, green >= 1

2. **Request Rate by Service** (Time Series)
   - Request rate (req/s) per service
   - 5-minute rate
   - Shows traffic patterns

3. **HTTP Status Codes Distribution** (Time Series)
   - Stacked percentage of 2xx, 3xx, 4xx, 5xx
   - Identifies error rates

4. **P95 Latency** (Stat)
   - 95th percentile request latency
   - Thresholds: green < 500ms, yellow < 2000ms, red >= 2000ms

**Latency Row**:
5. **Request Latency Percentiles by Service** (Time Series)
   - P50, P95, P99 latency per service
   - Helps identify slow services

**Bandwidth Row**:
6. **Bandwidth by Service** (Time Series)
   - Ingress and egress bandwidth per service
   - Shows data transfer patterns

**Health Row**:
7. **Upstream Target Health** (Table)
   - Health status of all upstream targets
   - Shows upstream, target, state, and health value

**Resources Row**:
8. **Kong CPU Usage** (Time Series)
   - CPU usage percentage per pod
   - Helps identify resource constraints

9. **Kong Memory Usage** (Time Series)
   - Memory usage in bytes per pod
   - Shows memory consumption trends

**Controller Row**:
10. **KIC Configuration Push Rate** (Time Series)
    - Successful and failed config pushes
    - Shows controller health

### Accessing Dashboards

```bash
# Open Grafana
open https://grafana.sg3.k3s.canhnv.com

# Login and search for: "Kong API Gateway - SG3"
```

### Dashboard Variables

The dashboard uses these variables:
- `cluster`: Fixed to "sg3"
- `namespace`: Fixed to "kong"

### Custom Dashboard

To create a custom dashboard:

1. **Access Grafana**
2. **Create New Dashboard**
3. **Add Panel** with queries:

**Example Panel - Request Rate**:
```promql
sum(rate(kong_http_requests_total{namespace="kong"}[5m])) by (service)
```

**Example Panel - Error Rate**:
```promql
sum(rate(kong_http_requests_total{namespace="kong", code=~"5.."}[5m]))
/
sum(rate(kong_http_requests_total{namespace="kong"}[5m]))
* 100
```

## Alerting

### Alert Rules

Location: `apps/kong/clusters/sg3/prometheus-alerts.yaml`

#### Critical Alerts

| Alert | Condition | Duration | Description |
|-------|-----------|----------|-------------|
| `KongGatewayDown` | Instance down | 2m | Single Kong instance unavailable |
| `KongGatewayAllDown` | All instances down | 1m | Complete outage |
| `KongVeryHighRequestLatencyP95` | P95 > 2000ms | 5m | Very high latency |
| `KongHigh5xxErrorRate` | 5xx > 1% | 5m | High error rate |
| `KongVeryHigh5xxErrorRate` | 5xx > 5% | 2m | Critical error rate |
| `KongAllUpstreamTargetsUnhealthy` | No healthy targets | 2m | Upstream service down |

#### Warning Alerts

| Alert | Condition | Duration | Description |
|-------|-----------|----------|-------------|
| `KongGatewayUnhealthy` | Last seen > 60s | 5m | Gateway health issues |
| `KongHighRequestLatencyP95` | P95 > 500ms | 5m | High latency |
| `KongHighInternalLatency` | Internal P95 > 50ms | 5m | Kong processing slow |
| `KongHigh4xxErrorRate` | 4xx > 5% | 5m | Client errors |
| `KongHighMemoryUsage` | Memory > 85% | 5m | Memory pressure |
| `KongHighCPUUsage` | CPU > 85% | 5m | CPU pressure |
| `KongPodRestarts` | Restarts > 0 | 5m | Pod instability |
| `KongUpstreamTargetUnhealthy` | Target unhealthy | 2m | Upstream target down |
| `KongIngressControllerConfigPushFailed` | Push failures > 0 | 5m | Controller issues |

#### Info Alerts

| Alert | Condition | Duration | Description |
|-------|-----------|----------|-------------|
| `KongHighBandwidthThroughput` | Egress > 100MB/s | 10m | High traffic |

### Viewing Active Alerts

**Prometheus UI**:
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open http://localhost:9090/alerts
```

**AlertManager UI**:
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# Open http://localhost:9093
```

**Grafana**:
- Navigate to Alerting → Alert Rules
- Filter by "kong"

### Alert Routing

Configure AlertManager receivers in:
`monitoring/clusters/sg3/alertmanager-config.yaml`

**Example Slack Integration**:
```yaml
receivers:
  - name: kong-alerts
    slack_configs:
      - api_url: <slack-webhook-url>
        channel: '#kong-alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

route:
  routes:
    - match:
        service: kong
      receiver: kong-alerts
```

## Common Queries

### Performance Queries

**Request Rate (per service)**:
```promql
sum(rate(kong_http_requests_total{namespace="kong"}[5m])) by (service)
```

**P50/P95/P99 Latency**:
```promql
# P50
histogram_quantile(0.50, sum(rate(kong_request_latency_ms_bucket[5m])) by (le, service))

# P95
histogram_quantile(0.95, sum(rate(kong_request_latency_ms_bucket[5m])) by (le, service))

# P99
histogram_quantile(0.99, sum(rate(kong_request_latency_ms_bucket[5m])) by (le, service))
```

**Latency Breakdown**:
```promql
# Kong processing latency
histogram_quantile(0.95, sum(rate(kong_kong_latency_ms_bucket[5m])) by (le))

# Upstream latency
histogram_quantile(0.95, sum(rate(kong_upstream_latency_ms_bucket[5m])) by (le))
```

### Error Rate Queries

**Overall Error Rate**:
```promql
sum(rate(kong_http_requests_total{code=~"5.."}[5m]))
/
sum(rate(kong_http_requests_total[5m]))
* 100
```

**Error Rate by Service**:
```promql
sum(rate(kong_http_requests_total{code=~"5.."}[5m])) by (service)
/
sum(rate(kong_http_requests_total[5m])) by (service)
* 100
```

**4xx vs 5xx**:
```promql
# 4xx rate
sum(rate(kong_http_requests_total{code=~"4.."}[5m]))

# 5xx rate
sum(rate(kong_http_requests_total{code=~"5.."}[5m]))
```

### Traffic Queries

**Total Traffic**:
```promql
sum(rate(kong_http_requests_total[5m]))
```

**Traffic by Status Code**:
```promql
sum(rate(kong_http_requests_total[5m])) by (code)
```

**Bandwidth Usage**:
```promql
# Ingress
sum(rate(kong_bandwidth_bytes{direction="ingress"}[5m])) by (service)

# Egress
sum(rate(kong_bandwidth_bytes{direction="egress"}[5m])) by (service)
```

### Health Queries

**Upstream Health**:
```promql
# Healthy targets
count(kong_upstream_target_health{state="healthy"} == 1) by (upstream)

# Unhealthy targets
count(kong_upstream_target_health{state="unhealthy"} == 1) by (upstream)
```

**Kong Instance Health**:
```promql
up{job="kong-gateway", namespace="kong"}
```

### Resource Queries

**CPU Usage**:
```promql
100 * (
  sum(rate(container_cpu_usage_seconds_total{namespace="kong", pod=~"kong-.*", container="kong"}[5m])) by (pod)
  /
  sum(container_spec_cpu_quota{namespace="kong", pod=~"kong-.*", container="kong"} / 100000) by (pod)
)
```

**Memory Usage**:
```promql
sum(container_memory_working_set_bytes{namespace="kong", pod=~"kong-.*", container="kong"}) by (pod)
```

**Memory Percentage**:
```promql
100 * (
  sum(container_memory_working_set_bytes{namespace="kong", pod=~"kong-.*", container="kong"}) by (pod)
  /
  sum(container_spec_memory_limit_bytes{namespace="kong", pod=~"kong-.*", container="kong"}) by (pod)
)
```

### Controller Queries

**Config Push Success Rate**:
```promql
sum(rate(ingress_controller_configuration_push_count{success="true"}[5m]))
/
sum(rate(ingress_controller_configuration_push_count[5m]))
* 100
```

**Config Push Latency**:
```promql
histogram_quantile(0.95,
  sum(rate(ingress_controller_configuration_push_duration_milliseconds_bucket[5m])) by (le)
)
```

**Translation Duration**:
```promql
histogram_quantile(0.95,
  sum(rate(ingress_controller_translation_count_bucket[5m])) by (le)
)
```

## Troubleshooting

### No Metrics in Prometheus

**Check ServiceMonitor**:
```bash
kubectl get servicemonitor -n kong -o yaml
```

**Verify labels match**:
- ServiceMonitor selector must match Service labels
- ServiceMonitor must have Prometheus discovery labels

**Check Prometheus Operator logs**:
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus-operator
```

### Metrics Not Updating

**Check Kong status endpoint**:
```bash
kubectl port-forward -n kong svc/kong-kong-status 8100:8100
curl http://localhost:8100/metrics
```

**Verify Prometheus plugin**:
```bash
kubectl get kongclusterplugin prometheus -o yaml
```

**Check scrape interval**:
```bash
# In Prometheus UI
# Status → Targets → kong-gateway
# Check "Last Scrape"
```

### Dashboard Not Loading

**Check ConfigMap**:
```bash
kubectl get configmap -n monitoring kong-dashboard
```

**Verify labels**:
```yaml
metadata:
  labels:
    grafana_dashboard: "1"  # Required for discovery
```

**Check Grafana logs**:
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

### Alerts Not Firing

**Check PrometheusRule**:
```bash
kubectl get prometheusrule -n monitoring kong-alerts -o yaml
```

**Verify alert evaluation**:
```bash
# In Prometheus UI
# Alerts → kong
# Check "State" column
```

**Test query manually**:
```bash
# In Prometheus UI
# Execute alert query
# Verify results
```

## Next Steps

- [Learn day-to-day operations](./OPERATIONS.md)
- [Review deployment guide](./DEPLOYMENT.md)
- [Explore Kong plugin examples](/apps/kong/README.md#plugin-examples)
