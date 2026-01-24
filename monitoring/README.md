# Monitoring Stack for K3s Clusters

This directory contains the monitoring infrastructure based on Prometheus and Grafana for all K3s clusters.

## Overview

We use the `kube-prometheus-stack` Helm chart which provides:

- **Prometheus**: Metrics collection and storage with 30-day retention
- **Grafana**: Visualization with pre-configured dashboards
- **Alertmanager**: Alert management and routing
- **Node Exporter**: System-level metrics from each node
- **kube-state-metrics**: Kubernetes object metrics

## Directory Structure

```
monitoring/
├── base/                        # Base configurations shared across clusters
│   ├── namespace.yaml          # Monitoring namespace definition
│   ├── kube-prometheus-stack/  # Base Helm values
│   └── dashboards/             # Custom dashboard definitions
├── clusters/                   # Cluster-specific configurations
│   ├── dev/                   # Development cluster
│   ├── production/            # Production clusters (eu, jp, sg, sg2, us, vn, vn2)
│   └── staging/               # Staging clusters (if any)
└── scripts/                   # Deployment and maintenance scripts
```

## Deployment

### Quick Deploy to Dev

```bash
cd monitoring
./scripts/deploy.sh dev
```

### Deploy to Other Clusters

```bash
./scripts/deploy.sh <cluster-name>
```

## Access

Each cluster has its own Grafana instance:

- Dev: <https://grafana.dev.k3s.canhnv.com>
- EU: <https://grafana.eu.k3s.canhnv.com>
- JP: <https://grafana.jp.k3s.canhnv.com>
- SG: <https://grafana.sg.k3s.canhnv.com>
- SG2: <https://grafana.sg2.k3s.canhnv.com>
- US: <https://grafana.us.k3s.canhnv.com> ✅ (Deployed)
- VN: <https://grafana.vn.k3s.canhnv.com>
- VN2: <https://grafana.vn2.k3s.canhnv.com>

## Default Credentials

Admin credentials are stored in Kubernetes secrets:

```bash
kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 -d
```

## Key Features

1. **Automatic Service Discovery**: Prometheus automatically discovers services with appropriate annotations
2. **30-Day Retention**: All metrics are retained for 1 month
3. **Pre-configured Dashboards**:
   - Kubernetes cluster overview
   - Node metrics
   - Pod/Container metrics
   - Namespace resource usage
   - K3s specific metrics
4. **Persistent Storage**: Grafana dashboards and Prometheus data are persisted

## Customization

To add cluster-specific configurations:

1. Copy `clusters/production/values-template.yaml` to `clusters/<cluster>/values.yaml`
2. Modify the values as needed
3. Update the ingress configuration in `clusters/<cluster>/ingress.yaml`
4. Deploy using the script: `./scripts/deploy.sh <cluster>`

## Documentation

- [Prometheus Configuration Guide](../docs/services/monitoring/PROMETHEUS.md)
- [Grafana Usage Guide](../docs/services/monitoring/GRAFANA.md)
- [Multi-cluster Setup](../docs/services/monitoring/MULTI_CLUSTER.md)
- [Troubleshooting](../docs/services/monitoring/TROUBLESHOOTING.md)
