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

## Kafka Monitoring

### Overview

The US cluster includes comprehensive monitoring for the production Kafka cluster using JMX Prometheus exporter integration.

### Dashboard

- **Name**: Kafka - US Cluster
- **UID**: `kafka-us-cluster`
- **Access**: Via Grafana UI under Dashboards

### Metrics Collected

The Kafka monitoring stack collects and visualizes:

**Cluster Health Metrics**:
- Broker count and availability
- Active controller status
- Partition distribution (total, leader, under-replicated, offline)

**Throughput Metrics**:
- Messages in per second (by broker and topic)
- Bytes in/out per second (by broker and topic)
- Request rates and latencies

**Resource Metrics**:
- Container CPU and memory usage
- JVM heap memory (used vs max)
- JVM garbage collection rates
- Thread counts

**Storage Metrics**:
- Log size by topic
- PVC usage percentage (with thresholds)
- Disk I/O metrics

### Alerts Configured

The following PrometheusRule alerts are configured for Kafka:

| Alert Name | Severity | Threshold | Description |
|------------|----------|-----------|-------------|
| `KafkaUnderReplicatedPartitions` | warning | > 0 for 5m | Partitions without enough in-sync replicas |
| `KafkaOfflinePartitions` | critical | > 0 for 1m | Partitions completely offline |
| `KafkaNoActiveController` | critical | < 1 for 1m | No active controller in cluster |
| `KafkaBrokerDown` | critical | < 2 for 2m | Insufficient brokers for HA |
| `KafkaDiskUsageHigh` | warning | > 80% for 5m | PVC usage approaching limit |
| `KafkaDiskUsageCritical` | critical | > 90% for 2m | PVC usage critically high |
| `KafkaHighMemoryUsage` | warning | > 90% for 5m | Container memory near limit |
| `KafkaHighCPUUsage` | warning | > 90% for 5m | Container CPU near limit |
| `KafkaJVMHeapUsageHigh` | warning | > 90% for 5m | JVM heap memory near max |
| `KafkaHighGCRate` | warning | > 10% time for 5m | Excessive garbage collection |

### Deployment

Apply the Kafka monitoring components:

```bash
# Apply the updated Kafka metrics configuration
kubectl apply -f /Users/canhnv/development/canhnv/k3s-ansible/kafka/clusters/us/kafka-cluster.yaml

# Apply the Grafana dashboard ConfigMap
kubectl apply -f /Users/canhnv/development/canhnv/k3s-ansible/monitoring/clusters/us/kafka-dashboard-configmap.yaml

# Apply the Prometheus alerts
kubectl apply -f /Users/canhnv/development/canhnv/k3s-ansible/monitoring/clusters/us/kafka-prometheus-alerts.yaml
```

After applying, the Grafana sidecar will automatically discover and load the dashboard within a few minutes.

### Troubleshooting

**Dashboard not appearing:**
```bash
# Check if the ConfigMap was created
kubectl get configmap -n monitoring kafka-dashboard

# Verify the label is correct
kubectl get configmap -n monitoring kafka-dashboard -o jsonpath='{.metadata.labels}'

# Check Grafana sidecar logs
kubectl logs -n monitoring deployment/kube-prometheus-stack-grafana -c grafana-sc-dashboard
```

**Metrics not showing:**
```bash
# Verify JMX exporter is running in Kafka pods
kubectl get pods -n kafka -l strimzi.io/cluster=kafka-us

# Check if metrics endpoint is accessible
kubectl exec -n kafka kafka-us-pool-0 -- curl localhost:9404/metrics

# Verify Prometheus is scraping Kafka pods
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Then visit http://localhost:9090/targets and search for "kafka"
```

**Alerts not firing:**
```bash
# Check if PrometheusRule was created
kubectl get prometheusrule -n monitoring kafka-alerts

# Verify Prometheus loaded the rules
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit http://localhost:9090/rules and search for "Kafka"

# Check alert status
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit http://localhost:9090/alerts
```

**Common issues:**

1. **JMX metrics not exported**: Ensure the `kafka-metrics-config` ConfigMap is properly mounted and Kafka pods have been restarted after the configuration update.

2. **Missing PVC metrics**: PVC usage metrics require kubelet metrics to be scraped. Verify that node-exporter and kubelet scraping are enabled in Prometheus.

3. **Dashboard shows "No data"**: Check the time range selector and verify that the Kafka cluster name matches `kafka-us` in the queries.

### Metric Retention

- Prometheus retention: 30 days (configured in values.yaml)
- To query older metrics, consider exporting to long-term storage (e.g., Thanos, Cortex)

### Next Steps

- Configure Alertmanager receivers (email, Slack, PagerDuty) for Kafka alerts
- Set up log aggregation with Loki for Kafka logs
- Create additional dashboards for topic-level or consumer group metrics
- Enable recording rules for frequently used queries to improve dashboard performance

## Security Notes

- Grafana is exposed via HTTPS with Let's Encrypt certificates
- Default admin password should be changed after first login
- Consider implementing RBAC for Grafana users
- Prometheus and Alertmanager are not exposed externally by default