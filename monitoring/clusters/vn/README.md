# VN Cluster Monitoring

This directory contains the monitoring configuration for the VN cluster.

## Overview

The VN cluster monitoring stack includes:

- **Prometheus**: Metrics collection with 20Gi storage
- **Grafana**: Visualization with 10Gi storage and Slack alerting
- **Alertmanager**: Alert management
- **Loki**: Log aggregation and querying
- **Node Exporter**: System-level metrics
- **kube-state-metrics**: Kubernetes object metrics

## Alerting

Grafana is configured to send alerts to Slack channels via webhooks.

### Alert Contact Points

- **slack-database**: Database-related alerts (PostgreSQL, MySQL, Redis)
  - Channel: `#alert-production-database`
  - Namespaces: `postgres.*|mysql.*|redis.*`

- **slack-murror-ai**: Murror AI application alerts
  - Channel: `#alert-production-murror-ai`
  - Namespaces: `nsp-prod-murror-ai.*`

- **slack-murror-api**: Murror API application alerts
  - Channel: `#alert-production-murror-api`
  - Namespaces: `nsp-prod-murror.*|murror-kol-prod-vn`

- **slack-vn-production**: General VN production alerts
  - Channel: Production monitoring channel

### Log-Based Alerts

Loki-based log alerts are configured for:

#### Murror API
1. **Error Log Detected**: Triggers when ERROR severity logs are detected (1m window)
2. **High Error Rate**: Triggers when error rate exceeds 0.1 errors/sec for 5 minutes

#### Murror AI
1. **Error Log Detected**: Triggers when ERROR severity logs are detected (1m window)
2. **High Error Rate**: Triggers when error rate exceeds 0.1 errors/sec for 5 minutes

### Configuration Files

- `grafana-alerting-config.yaml`: Contact points and notification policies
- `murror-api-log-alert-rules.yaml`: Loki-based log alert rules for Murror API
- `murror-ai-log-alert-rules.yaml`: Loki-based log alert rules for Murror AI
- `murror-ai-prometheus-alerts.yaml`: Prometheus-based alerts for Murror AI pods
- `murror-ai-dashboard-configmap.yaml`: Grafana dashboard for Murror AI logs & metrics
- `loki-datasource.yaml`: Loki datasource configuration (UID: P8E80F9AEF21F6940)

## Access

- **Grafana**: <https://grafana.vn.k3s.canhnv.com>
- **Prometheus**: <https://prometheus.vn.k3s.canhnv.com>

### Grafana Admin Credentials

Retrieve the admin password:

```bash
kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d
```

Current admin password: `prom-operator`

## Deployment

To deploy or update the monitoring stack:

```bash
cd monitoring
./scripts/deploy.sh vn
```

## Configuration

- **Storage**:
  - Prometheus: 20Gi (30-day retention)
  - Grafana: 10Gi
  - Alertmanager: 20Gi

- **Resources**:
  - Prometheus: 1 CPU, 4Gi memory (8Gi limit)
  - Grafana: 250m CPU, 512Mi memory (1Gi limit)

## TLS Certificates

Certificates are managed by cert-manager using the `canhnv-com-staging` cluster issuer.

## Troubleshooting

### Check pod status

```bash
kubectl get pods -n monitoring
```

### Check ingress status

```bash
kubectl get ingress -n monitoring
```

### Check certificate status

```bash
kubectl get certificate -n monitoring
```

### View Prometheus logs

```bash
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0
```

### View Grafana logs

```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

## Deployment Notes

After applying the alerting configuration files:

```bash
kubectl apply -f grafana-alerting-config.yaml
kubectl apply -f murror-api-log-alert-rules.yaml
kubectl apply -f murror-ai-log-alert-rules.yaml
kubectl apply -f murror-ai-prometheus-alerts.yaml
kubectl apply -f murror-ai-dashboard-configmap.yaml
```

Grafana sidecar will automatically discover and load these configurations within a few minutes.

## Last Updated

2026-01-22 - Added Murror AI monitoring with dashboard, log alerts, and Prometheus alerts
2026-01-21 - Added Grafana alerting with Slack integration
2025-08-02 - Initial deployment with external access configured
