# VN Cluster Monitoring

This directory contains the monitoring configuration for the VN cluster.

## Overview

The VN cluster monitoring stack includes:

- **Prometheus**: Metrics collection with 20Gi storage
- **Grafana**: Visualization with 10Gi storage
- **Alertmanager**: Alert management
- **Node Exporter**: System-level metrics
- **kube-state-metrics**: Kubernetes object metrics

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

## Last Updated

2025-08-02 - Initial deployment with external access configured
