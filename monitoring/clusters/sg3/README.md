# SG3 Cluster Monitoring

Monitoring stack for the sg3 production cluster (Singapore OVH).

## Deployment Information

- **Cluster**: sg3 (8 nodes: 3 control plane + 5 workers)
- **K3s Version**: v1.32.5+k3s1
- **Deployed**: November 25, 2025
- **Helm Chart**: kube-prometheus-stack
- **Namespace**: monitoring

## Components

### Metrics Collection
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert routing and management
- **Node Exporter**: Node-level metrics (DaemonSet on all 8 nodes)
- **kube-state-metrics**: Kubernetes object metrics
- **Prometheus Operator**: CRD management

### Log Aggregation
- **Loki**: Log aggregation and querying (Simple Scalable Deployment)
  - Write Path: 3 replicas (log ingestion)
  - Read Path: 2 replicas (log queries)
  - Backend: 1 replica (compaction)
  - Gateway: 2 replicas (NGINX load balancer)
- **Promtail**: Log collection agent (DaemonSet on all 8 nodes)

## Storage Configuration

All persistent volumes use **Longhorn distributed storage** with 3 replicas:

| Component | Storage | Storage Class | Replicas |
|-----------|---------|---------------|----------|
| Prometheus | 25Gi | longhorn | 3 |
| Grafana | 25Gi | longhorn | 3 |
| Alertmanager | 25Gi | longhorn | 3 |
| Loki Write | 50Gi | longhorn | 3 |
| Loki Read | 50Gi | longhorn | 3 |
| Loki Backend | 50Gi | longhorn | 3 |

**Metrics Stack**: 75Gi (225Gi raw with replication)
**Logging Stack**: 150Gi (450Gi raw with replication)
**Total**: 225Gi logical (675Gi raw with replication)

## Access Information

### Grafana
- **URL**: https://grafana.sg3.k3s.canhnv.com
- **Username**: admin
- **Password**: Get from secret:
  ```bash
  kubectl get secret -n monitoring kube-prometheus-stack-grafana \
    -o jsonpath="{.data.admin-password}" | base64 -d && echo
  ```

### Prometheus
- **Internal**: http://kube-prometheus-stack-prometheus.monitoring.svc:9090
- **Port Forward**:
  ```bash
  kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
  ```
- **External URL** (optional): https://prometheus.sg3.k3s.canhnv.com

### Alertmanager
- **Internal**: http://kube-prometheus-stack-alertmanager.monitoring.svc:9093
- **Port Forward**:
  ```bash
  kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
  ```

### Loki
- **External URL**: https://loki.sg3.k3s.canhnv.com
- **Internal**: http://loki-gateway.monitoring.svc.cluster.local
- **Grafana Datasource**: Auto-configured (name: "Loki")
- **Log Retention**: 15 days
- **Access via Grafana**:
  1. Open https://grafana.sg3.k3s.canhnv.com
  2. Go to Explore
  3. Select "Loki" datasource
  4. Query logs: `{namespace="monitoring"}` or `{pod=~"postgres.*"}`

## Resource Usage

### Metrics Stack
- **CPU**: ~2 cores
- **Memory**: ~3.5Gi
- **Storage**: 75Gi persistent (225Gi raw)

### Logging Stack
- **CPU**: ~3.25 cores (Write: 1.5, Read: 1, Backend: 0.25, Gateway: 0.2, Promtail: 0.8)
- **Memory**: ~6.3Gi (Write: 3Gi, Read: 2Gi, Backend: 512Mi, Gateway: 256Mi, Promtail: 1Gi)
- **Storage**: 150Gi persistent (450Gi raw)

### Total Monitoring + Logging
- **CPU**: ~5.25 cores
- **Memory**: ~9.8Gi
- **Storage**: 225Gi persistent (675Gi raw)

## Deployment Commands

### Metrics Stack (Prometheus/Grafana)

```bash
cd /Users/canhnv/development/canhnv/k3s-ansible/monitoring
./scripts/deploy.sh sg3
```

### Logging Stack (Loki)

```bash
cd /Users/canhnv/development/canhnv/k3s-ansible/monitoring
./scripts/deploy-loki.sh sg3
```

### Verify Deployment

```bash
# Check all monitoring pods (metrics + logs)
kubectl get pods -n monitoring

# Check PVCs (should be Bound with longhorn storage)
kubectl get pvc -n monitoring

# Check ingresses and certificates
kubectl get ingress,certificate -n monitoring

# Check Longhorn volumes
kubectl get volumes -n longhorn-system | grep monitoring

# Test Loki specifically
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://loki-gateway.monitoring.svc.cluster.local/ready

# Query logs from Loki
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -G http://loki-gateway.monitoring.svc.cluster.local/loki/api/v1/query \
  --data-urlencode 'query={namespace="monitoring"}' \
  --data-urlencode 'limit=10'
```

## Monitoring Longhorn

Longhorn metrics are automatically discovered via ServiceMonitor:

1. Check ServiceMonitor exists:
   ```bash
   kubectl get servicemonitor -n longhorn-system
   ```

2. Verify Prometheus is scraping Longhorn:
   - Open Grafana
   - Go to Explore
   - Query: `longhorn_volume_actual_size_bytes`

3. Import Longhorn dashboard:
   - Dashboard ID: 13032 (official Longhorn dashboard)
   - Or create custom dashboards

## Troubleshooting

### Pods not starting

```bash
# Check events
kubectl get events -n monitoring --sort-by='.lastTimestamp'

# Check pod logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

### PVC stuck in Pending

```bash
# Check PVC status
kubectl describe pvc -n monitoring

# Check Longhorn availability
kubectl get pods -n longhorn-system
kubectl get volumes -n longhorn-system
```

### Certificate issues

```bash
# Check certificate status
kubectl get certificate -n monitoring
kubectl describe certificate grafana-sg3-tls -n monitoring

# Check cert-manager logs
kubectl logs -n cert-manager deploy/cert-manager -f
```

### Metrics not showing

```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open http://localhost:9090/targets

# Check ServiceMonitors
kubectl get servicemonitor -A
```

## Backup and Recovery

Longhorn provides automatic volume snapshots and backups:

1. Configure backup target in Longhorn UI
2. Enable recurring snapshots for monitoring PVCs
3. Test recovery procedures

## Maintenance

### Update Alert Configuration

Edit `values.yaml` and redeploy:

```bash
cd /Users/canhnv/development/canhnv/k3s-ansible/monitoring
./scripts/deploy.sh sg3
```

### Add Custom Dashboards

Import via Grafana UI or create ConfigMaps with label `grafana_dashboard: "1"`

### Scale Components

Update replica counts in `values.yaml` if needed for HA
