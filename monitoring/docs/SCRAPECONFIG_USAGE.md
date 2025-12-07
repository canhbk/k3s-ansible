# Using ScrapeConfig with Prometheus

The Prometheus instance in our monitoring stack is now configured to discover and use ScrapeConfig custom resources from any namespace.

## Configuration

The following selectors have been configured in the Prometheus instance:

```yaml
scrapeConfigSelector:
  matchLabels:
    prometheus: kube-prometheus-stack
scrapeConfigNamespaceSelector: {}  # Empty selector means all namespaces
```

This means:

- Prometheus will pick up any `ScrapeConfig` resource that has the label `prometheus: kube-prometheus-stack`
- ScrapeConfigs can be created in **any namespace** (not just the monitoring namespace)

## Creating a ScrapeConfig

To create a ScrapeConfig that will be picked up by Prometheus, ensure it has the required label:

```yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: ScrapeConfig
metadata:
  name: my-app-scrape
  namespace: my-namespace  # Can be any namespace
  labels:
    prometheus: kube-prometheus-stack  # Required label
spec:
  staticConfigs:
  - targets:
    - 'my-service.my-namespace.svc.cluster.local:8080'
  metricsPath: '/metrics'
  scrapeInterval: '30s'
```

## Common Use Cases

### 1. Scraping Services in Other Namespaces

```yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: ScrapeConfig
metadata:
  name: app-metrics
  namespace: production
  labels:
    prometheus: kube-prometheus-stack
spec:
  kubernetesSDConfigs:
  - role: endpoints
    namespaces:
      names:
      - production
    selectors:
    - role: endpoints
      label: "app=my-app"
```

### 2. Scraping External Services

```yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: ScrapeConfig
metadata:
  name: external-service
  namespace: monitoring
  labels:
    prometheus: kube-prometheus-stack
spec:
  staticConfigs:
  - targets:
    - 'external-db.example.com:9090'
    - 'external-cache.example.com:9091'
  scheme: 'https'
  tlsConfig:
    insecureSkipVerify: true
```

### 3. Service Discovery with Relabeling

```yaml
apiVersion: monitoring.coreos.com/v1alpha1
kind: ScrapeConfig
metadata:
  name: pod-discovery
  namespace: default
  labels:
    prometheus: kube-prometheus-stack
spec:
  kubernetesSDConfigs:
  - role: pod
    namespaces:
      names:
      - default
      - production
  relabelConfigs:
  - sourceLabels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
    action: keep
    regex: true
  - sourceLabels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
    action: replace
    targetLabel: __metrics_path__
    regex: (.+)
  - sourceLabels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
    action: replace
    regex: ([^:]+)(?::\d+)?;(\d+)
    replacement: $1:$2
    targetLabel: __address__
```

## Verifying ScrapeConfig

After creating a ScrapeConfig, you can verify it's been picked up:

1. Check if the ScrapeConfig exists:

   ```bash
   kubectl get scrapeconfig -A
   ```

2. Check Prometheus targets:
   - Access Prometheus UI: <https://prometheus.dev.k3s.canhnv.com>
   - Go to Status → Targets
   - Look for your scrape job

3. Check Prometheus configuration:

   ```bash
   kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -- cat /etc/prometheus/config_out/prometheus.env.yaml | grep -A 20 "job_name:"
   ```

## Best Practices

1. **Use descriptive names**: Name your ScrapeConfig resources clearly to identify what they're scraping
2. **Namespace organization**: Place ScrapeConfigs in the same namespace as the services they're monitoring
3. **Label consistently**: Always include the required `prometheus: kube-prometheus-stack` label
4. **Test configurations**: Validate your scrape configs before applying them in production
5. **Monitor targets**: Regularly check the Prometheus targets page for failed scrapes

## Troubleshooting

If your ScrapeConfig isn't being picked up:

1. Verify the label is correct:

   ```bash
   kubectl get scrapeconfig <name> -n <namespace> -o yaml | grep -A 2 labels
   ```

2. Check Prometheus logs:

   ```bash
   kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0 prometheus
   ```

3. Ensure the ScrapeConfig CRD is installed:

   ```bash
   kubectl get crd | grep scrapeconfig
   ```
