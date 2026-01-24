# Monitoring Services Overview

This documentation covers the monitoring infrastructure deployed across all K3s clusters using Prometheus and Grafana.

## Architecture

```text
┌─────────────────────────────────────────────────────────┐
│                    K3s Cluster                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │  Prometheus  │  │   Grafana    │  │ Alertmanager │ │
│  │              │  │              │  │              │ │
│  │ • Metrics    │  │ • Dashboards │  │ • Alerts     │ │
│  │ • Storage    │  │ • Queries    │  │ • Routes     │ │
│  │ • PromQL     │  │ • Users      │  │ • Silences   │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │
│         │                  │                  │         │
│  ┌──────┴──────────────────┴──────────────────┴──────┐ │
│  │              Service Discovery                     │ │
│  └────────────────────────────────────────────────────┘ │
│         │                  │                  │         │
│  ┌──────┴───────┐  ┌──────┴───────┐  ┌──────┴──────┐ │
│  │Node Exporters│  │ ServiceMons  │  │ PodMonitors │ │
│  └──────────────┘  └──────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Components

### Prometheus

- **Purpose**: Time-series database for metrics collection and storage
- **Retention**: 30 days (configurable per cluster)
- **Features**:
  - Automatic service discovery
  - PromQL query language
  - Recording rules
  - Alert evaluation

### Grafana

- **Purpose**: Visualization and dashboarding
- **Access**: HTTPS with TLS (grafana.{cluster}.k3s.canhnv.com)
- **Features**:
  - Pre-configured dashboards
  - User management
  - Alert visualization
  - Multiple data sources

### Alertmanager

- **Purpose**: Alert routing and management
- **Features**:
  - Alert grouping
  - Silencing
  - Inhibition
  - Multiple notification channels

### Node Exporter

- **Purpose**: Hardware and OS metrics from nodes
- **Metrics**: CPU, memory, disk, network, etc.

### kube-state-metrics

- **Purpose**: Kubernetes object state metrics
- **Metrics**: Deployments, pods, nodes, etc.

## Deployment

The monitoring stack is deployed using:

- **Helm Chart**: kube-prometheus-stack
- **Namespace**: monitoring
- **Base Configuration**: `monitoring/base/`
- **Cluster Overrides**: `monitoring/clusters/{cluster}/`

## Access Points

Each cluster has its own monitoring instance:

| Cluster | Grafana URL | Environment |
|---------|-------------|-------------|
| dev | <https://grafana.dev.k3s.canhnv.com> | Development |
| eu | <https://grafana.eu.k3s.canhnv.com> | Production |
| jp | <https://grafana.jp.k3s.canhnv.com> | Production |
| sg | <https://grafana.sg.k3s.canhnv.com> | Production |
| sg2 | <https://grafana.sg2.k3s.canhnv.com> | Production |
| us | <https://grafana.us.k3s.canhnv.com> | Production |
| vn | <https://grafana.vn.k3s.canhnv.com> | Production |
| vn2 | <https://grafana.vn2.k3s.canhnv.com> | Production |

## Default Dashboards

1. **Kubernetes / Compute Resources / Cluster**
   - Overall cluster resource usage
   - CPU and memory by namespace

2. **Kubernetes / Compute Resources / Node**
   - Per-node resource usage
   - Pod distribution

3. **Kubernetes / Compute Resources / Pod**
   - Individual pod metrics
   - Container resource usage

4. **Node Exporter Full**
   - Detailed system metrics
   - Disk, network, CPU details

5. **Kubernetes / Networking**
   - Network traffic metrics
   - Service communication

## Service Discovery

Prometheus automatically discovers targets through:

1. **ServiceMonitor CRDs**

   ```yaml
   apiVersion: monitoring.coreos.com/v1
   kind: ServiceMonitor
   metadata:
     name: my-app
   spec:
     selector:
       matchLabels:
         app: my-app
     endpoints:
     - port: metrics
   ```

2. **Pod Annotations**

   ```yaml
   annotations:
     prometheus.io/scrape: "true"
     prometheus.io/port: "8080"
     prometheus.io/path: "/metrics"
   ```

## Storage Requirements

Per cluster (approximate):

- **Prometheus**: 60-100Gi (30-day retention)
- **Grafana**: 5-20Gi (dashboards and config)
- **Alertmanager**: 5-20Gi (alert history)

## Related Documentation

- [Prometheus Configuration](./PROMETHEUS.md)
- [Grafana Usage Guide](./GRAFANA.md)
- [Multi-Cluster Setup](./MULTI_CLUSTER.md)
- [Monitoring New Services](./MONITORING_NEW_SERVICES.md)
- [Troubleshooting](./TROUBLESHOOTING.md)
