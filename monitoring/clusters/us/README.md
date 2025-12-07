# Monitoring Configuration for US Cluster

## Overview

This directory contains the monitoring configuration for the US production cluster using kube-prometheus-stack.

## Deployment

```bash
# From monitoring directory
./scripts/deploy.sh us
```

## Access

- **Grafana**: https://grafana.us.k3s.canhnv.com
- **Username**: admin
- **Password**: Run `kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d`

## Components

### Prometheus
- **Storage**: 100Gi with 30-day retention
- **Resources**: 1 CPU, 4Gi memory (8Gi limit)
- **Access**: Port-forward for direct access
  ```bash
  kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
  ```

### Grafana
- **Storage**: 20Gi persistent volume
- **Resources**: 250m CPU, 512Mi memory (1Gi limit)
- **External Access**: Via Traefik ingress with Let's Encrypt TLS

### Alertmanager
- **Storage**: 20Gi persistent volume
- **Resources**: 100m CPU, 128Mi memory (256Mi limit)
- **Access**: Port-forward for direct access
  ```bash
  kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
  ```

## Monitoring Targets

The stack automatically discovers and monitors:
- All Kubernetes nodes (via node-exporter)
- Kubernetes API server
- Kubernetes controller manager
- Kubernetes scheduler
- CoreDNS
- Kubelet metrics
- Container metrics

## Custom Dashboards

Pre-configured dashboards include:
- Kubernetes cluster overview
- Node metrics and resource usage
- Pod and container metrics
- Namespace resource quotas
- Persistent volume usage

## Alerts

Default alerts are configured for:
- Node down
- High CPU/Memory usage
- Disk space issues
- Pod crashes and restarts
- API server availability

## Maintenance

### Updating Configuration

1. Edit `values.yaml` with your changes
2. Run the deployment script: `./scripts/deploy.sh us`

### Backup Grafana Dashboards

```bash
# Use the backup script
../../../scripts/backup-dashboards.sh us
```

### Troubleshooting

Check pod status:
```bash
kubectl get pods -n monitoring
```

View logs:
```bash
# Prometheus
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0

# Grafana
kubectl logs -n monitoring deployment/kube-prometheus-stack-grafana

# Alertmanager
kubectl logs -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0
```

## Security Notes

- Grafana is exposed via HTTPS with Let's Encrypt certificates
- Default admin password should be changed after first login
- Consider implementing RBAC for Grafana users
- Prometheus and Alertmanager are not exposed externally by default