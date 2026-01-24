# SG3 Cluster Monitoring

This document describes the monitoring setup for the SG3 cluster, including Prometheus, Grafana, Loki, and alerting configuration.

## Overview

The SG3 cluster uses the kube-prometheus-stack for comprehensive monitoring and alerting:

- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert routing and notification
- **Loki**: Log aggregation and querying
- **Node Exporter**: Node-level metrics
- **Kube State Metrics**: Kubernetes object metrics

## Access

- **Grafana**: https://grafana.sg3.k3s.canhnv.com/
- **Loki**: https://loki.sg3.k3s.canhnv.com/

## Storage

All monitoring components use Longhorn distributed storage:

- **Prometheus**: 25Gi (15 days retention, 20GB size limit)
- **Grafana**: 25Gi
- **Alertmanager**: 25Gi
- **Loki**: Configured separately (see loki-values.yaml)

## Alerting Configuration

### Slack Integration

Alerts are sent to Slack channels based on severity and namespace:

| Channel | Purpose | Receiver |
|---------|---------|----------|
| `#alert-sg3-cluster` | General cluster alerts | production-alerts |
| `#alert-sg3-critical` | Critical severity alerts | critical-alerts |
| `#alert-sg3-murror-api` | Murror API specific alerts | murror-api-alerts |
| `#alert-sg3-murror-ai` | Murror AI specific alerts | murror-ai-alerts |

**Slack Webhook URL**: Configured in `monitoring/clusters/sg3/values.yaml` under `alertmanager.config.global.slack_api_url`

### Alert Routing

Alertmanager routes alerts based on these rules:

1. **Critical Alerts**: Any alert with `severity: critical` goes to `#alert-sg3-critical`
2. **Murror AI Alerts**: Any alert from namespace `nsp-alpha-murror-ai` goes to `#alert-sg3-murror-ai`
3. **Murror API Alerts**: Any alert from namespace `nsp-alpha-murror` goes to `#alert-sg3-murror-api`
4. **Default**: All other alerts go to `#alert-sg3-cluster`

### Silenced Alerts

The following alerts are routed to the null receiver (silenced):

- **Watchdog**: Heartbeat alert used for monitoring Alertmanager health
- **InfoInhibitor**: Meta-alert used to trigger info-level inhibition
- **Any alert with `severity: info`**: Info-level alerts are considered low priority and do not trigger Slack notifications

### Alert Inhibition

The following inhibition rules are configured to prevent alert fatigue:

1. **InfoInhibitor Suppression**: When `InfoInhibitor` alert fires, all `severity="info"` alerts in the same namespace are suppressed
2. **Critical Inhibits Warning**: When a critical alert fires, warning alerts with the same alertname and namespace are suppressed

This ensures that lower-priority alerts don't create noise when higher-priority issues are already being addressed.

### Alert Grouping

- **Group By**: alertname, cluster, service
- **Group Wait**: 10s
- **Group Interval**: 10s
- **Repeat Interval**: 12h (5m for Murror API alerts)

## Murror API Alerting

Special alerting is configured for the Murror API application in namespace `nsp-alpha-murror`.

### Log-Based Alerts (Grafana + Loki)

Configured in `murror-api-log-alert-rules.yaml`:

| Alert | Condition | For | Severity | Description |
|-------|-----------|-----|----------|-------------|
| `murror-api-error-log-detected` | Any ERROR log appears | 0s | warning | Fires immediately when any error log is detected |
| `murror-api-high-error-rate` | Error rate > 0.1/sec | 5m | critical | Sustained high error rate |

**Loki Query**: `{namespace="nsp-alpha-murror", app="murror-api"} | json | severity="ERROR"`

**Datasource UID**: `P8E80F9AEF21F6940`

### Pod-Level Alerts (PrometheusRule)

Configured in `murror-api-prometheus-alerts.yaml`:

| Alert | Condition | For | Severity | Description |
|-------|-----------|-----|----------|-------------|
| `MurrorAPIPodNotReady` | Pod not ready | 5m | warning | Pod stuck in non-ready state |
| `MurrorAPIPodRestarts` | Restarts detected | 5m | warning | Pod is restarting |
| `MurrorAPIContainerCrashLooping` | High restart rate | 5m | critical | Container crash looping |
| `MurrorAPIDeploymentReplicasMismatch` | Replicas mismatch | 10m | warning | Not enough replicas available |
| `MurrorAPIHighMemoryUsage` | Memory > 90% | 5m | warning | High memory usage |
| `MurrorAPINoPodsRunning` | No running pods | 5m | critical | Complete service outage |

## Murror AI Alerting

Special alerting is configured for the Murror AI application in namespace `nsp-alpha-murror-ai`.

### Log-Based Alerts (Grafana + Loki)

Configured in `murror-ai-log-alert-rules.yaml`:

| Alert | Condition | For | Severity | Description |
|-------|-----------|-----|----------|-------------|
| `murror-ai-error-log-detected` | Any ERROR/CRITICAL log appears | 0s | warning | Fires immediately when any error log is detected |
| `murror-ai-high-error-rate` | Error rate > 0.1/sec | 5m | critical | Sustained high error rate |

**Loki Query**: `{namespace="nsp-alpha-murror-ai", app_kubernetes_io_name="murror-ai"} |~ "(?i)(ERROR|CRITICAL)"`

**Datasource UID**: `P8E80F9AEF21F6940`

**Note**: Murror AI uses plain text logs with regex pattern matching (not JSON parsing).

### Pod-Level Alerts (PrometheusRule)

Configured in `murror-ai-prometheus-alerts.yaml`:

| Alert | Condition | For | Severity | Description |
|-------|-----------|-----|----------|-------------|
| `MurrorAIPodNotReady` | Pod not ready | 5m | warning | Pod stuck in non-ready state |
| `MurrorAIPodRestarts` | Restarts detected | 5m | warning | Pod is restarting |
| `MurrorAIContainerCrashLooping` | High restart rate | 5m | critical | Container crash looping |
| `MurrorAIDeploymentReplicasMismatch` | Replicas mismatch | 10m | warning | Not enough replicas available |
| `MurrorAIHighMemoryUsage` | Memory > 90% | 5m | warning | High memory usage |
| `MurrorAINoPodsRunning` | No running pods | 5m | critical | Complete service outage |
| `MurrorAICeleryWorkerNotReady` | Celery worker not ready | 5m | warning | Celery worker pod not ready |

### Grafana Dashboard

A dedicated dashboard is available at: **Murror AI - Logs & Metrics**

Panels include:
- CPU and Memory usage gauges
- CPU and Memory usage by pod (time series)
- Live logs panel
- Error logs panel
- Warning logs panel
- Error rate time series

### Slack Notifications

Alerts are sent to: **#alert-sg3-murror-ai**

Contact point configuration in `grafana-alerting-config.yaml` and `values.yaml`

### Verification Commands

```bash
# Check PrometheusRule
kubectl get prometheusrule -n monitoring murror-ai-alerts

# Check Grafana ConfigMaps
kubectl get configmap -n monitoring | grep murror-ai

# Check Grafana dashboard
kubectl get configmap -n monitoring murror-ai-dashboard -o yaml

# View Grafana log alert rules
kubectl get configmap -n monitoring murror-ai-log-alert-rules -o yaml

# Check active alerts in Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Then visit http://localhost:9090/alerts and filter by "murror-ai"

# Check Grafana alerts
# Visit https://grafana.sg3.k3s.canhnv.com/alerting/list and search "Murror AI"
```

## Configuration Files

| File | Purpose |
|------|---------|
| `monitoring/clusters/sg3/values.yaml` | Main Helm values for kube-prometheus-stack |
| `monitoring/clusters/sg3/grafana-alerting-config.yaml` | Grafana contact points and notification policies |
| `monitoring/clusters/sg3/murror-api-log-alert-rules.yaml` | Grafana alert rules for Murror API Loki logs |
| `monitoring/clusters/sg3/murror-api-prometheus-alerts.yaml` | Prometheus alert rules for Murror API pods |
| `monitoring/clusters/sg3/murror-api-dashboard-configmap.yaml` | Grafana dashboard for Murror API |
| `monitoring/clusters/sg3/murror-ai-log-alert-rules.yaml` | Grafana alert rules for Murror AI Loki logs |
| `monitoring/clusters/sg3/murror-ai-prometheus-alerts.yaml` | Prometheus alert rules for Murror AI pods |
| `monitoring/clusters/sg3/murror-ai-dashboard-configmap.yaml` | Grafana dashboard for Murror AI |
| `monitoring/clusters/sg3/loki-values.yaml` | Loki Helm values |
| `monitoring/clusters/sg3/loki-datasource.yaml` | Grafana datasource for Loki |

## Deployment

### Deploy Monitoring Stack

```bash
# Deploy kube-prometheus-stack with custom values
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values monitoring/clusters/sg3/values.yaml
```

### Apply Alert Rules

```bash
# Apply Grafana alerting configuration
kubectl apply -f monitoring/clusters/sg3/grafana-alerting-config.yaml

# Apply Murror API alert rules
kubectl apply -f monitoring/clusters/sg3/murror-api-log-alert-rules.yaml
kubectl apply -f monitoring/clusters/sg3/murror-api-prometheus-alerts.yaml
kubectl apply -f monitoring/clusters/sg3/murror-api-dashboard-configmap.yaml

# Apply Murror AI alert rules
kubectl apply -f monitoring/clusters/sg3/murror-ai-log-alert-rules.yaml
kubectl apply -f monitoring/clusters/sg3/murror-ai-prometheus-alerts.yaml
kubectl apply -f monitoring/clusters/sg3/murror-ai-dashboard-configmap.yaml
```

### Verify Alerts

```bash
# Check PrometheusRule
kubectl get prometheusrule -n monitoring murror-api-alerts

# Check Grafana ConfigMaps
kubectl get configmap -n monitoring | grep murror-api

# View Alertmanager configuration
kubectl get secret -n monitoring alertmanager-kube-prometheus-stack-alertmanager -o yaml

# Check active alerts in Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Then visit http://localhost:9090/alerts

# Check Grafana alerts
# Visit https://grafana.sg3.k3s.canhnv.com/alerting/list
```

## Troubleshooting

### Test Slack Notifications

```bash
# Port-forward to Alertmanager
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093

# Send test alert
curl -X POST http://localhost:9093/api/v2/alerts -H "Content-Type: application/json" -d '[
  {
    "labels": {
      "alertname": "TestAlert",
      "severity": "warning",
      "namespace": "nsp-alpha-murror",
      "app": "murror-api"
    },
    "annotations": {
      "summary": "Test alert from Alertmanager",
      "description": "This is a test alert to verify Slack integration"
    }
  }
]'
```

### Check Alertmanager Status

```bash
# View Alertmanager configuration
kubectl exec -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 -- amtool config show

# Check active alerts
kubectl exec -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 -- amtool alert

# View silences
kubectl exec -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 -- amtool silence query
```

### View Logs

```bash
# Alertmanager logs
kubectl logs -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 -f

# Prometheus logs
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -f

# Grafana logs
kubectl logs -n monitoring deployment/kube-prometheus-stack-grafana -f
```

## Maintenance

### Update Slack Webhook

1. Edit `monitoring/clusters/sg3/values.yaml`
2. Update `alertmanager.config.global.slack_api_url`
3. Redeploy: `helm upgrade kube-prometheus-stack ...`

### Add New Alert Rules

**For Prometheus metrics:**
1. Edit `monitoring/clusters/sg3/murror-api-prometheus-alerts.yaml`
2. Add new alert rule under `spec.groups[0].rules`
3. Apply: `kubectl apply -f monitoring/clusters/sg3/murror-api-prometheus-alerts.yaml`

**For Loki logs:**
1. Edit `monitoring/clusters/sg3/murror-api-log-alert-rules.yaml`
2. Add new alert rule under `groups[0].rules`
3. Apply: `kubectl apply -f monitoring/clusters/sg3/murror-api-log-alert-rules.yaml`

### Modify Alert Thresholds

Edit the respective alert rule file and update the `expr` or query parameters, then reapply.

## Best Practices

1. **Test alerts before production**: Use the test procedure above
2. **Monitor alert fatigue**: Adjust thresholds if alerts are too noisy
3. **Document alert responses**: Create runbooks for each alert
4. **Regular reviews**: Review and tune alerts based on actual incidents
5. **Silence during maintenance**: Use Alertmanager silences during planned maintenance

## References

- [Prometheus Alerting](https://prometheus.io/docs/alerting/latest/overview/)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [Grafana Alerting](https://grafana.com/docs/grafana/latest/alerting/)
- [Loki LogQL](https://grafana.com/docs/loki/latest/logql/)
