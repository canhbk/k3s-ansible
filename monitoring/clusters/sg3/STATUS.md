# Monitoring Status - SG3 Cluster

**Last Updated**: 2025-12-08

## Current Status

### ✅ Fixed

- Grafana is now running and accessible
- Dashboard ConfigMap deployed with CPU, RAM, Disk panels

### ⚠️ Partial Fix

- ServiceMonitors labeled: Added `prometheus: kube-prometheus-stack` label to:
  - kube-prometheus-stack-kube-state-metrics
  - kube-prometheus-stack-prometheus-node-exporter

### ❌ Still Not Working

- Container metrics (CPU, RAM, Disk) showing "No data" in dashboard
- WARN and DEBUG logs not visible (only INFO and ERROR showing)

## Quick Verification Steps

### 1. Check if Grafana is accessible

```bash
# Should return "ok"
kubectl exec -n monitoring -l app.kubernetes.io/name=grafana -c grafana -- wget -qO- http://localhost:3000/api/health | jq -r '.database'
```

### 2. Access Grafana Dashboard

- URL: <https://grafana.sg3.k3s.canhnv.com>
- Navigate to "Murror API - Logs & Metrics"
- Select namespace: nsp-alpha-murror

### 3. Check if metrics are being collected

```bash
# Port forward Prometheus
kubectl port-forward -n monitoring prometheus-kube-prometheus-stack-prometheus-0 9090:9090

# Open in browser: http://localhost:9090
# Go to Status > Targets
# Look for:
#   - serviceMonitor/monitoring/kube-prometheus-stack-kube-state-metrics/0
#   - serviceMonitor/monitoring/kube-prometheus-stack-kubelet/*/metrics/cadvisor
```

## Next Steps to Fix Metrics

### Option A: Wait for Prometheus to Scrape (Simple)

The ServiceMonitors were just patched. Prometheus may need time to discover and scrape them.

```bash
# Wait 2-3 minutes, then check
kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -c prometheus -- \
  sh -c 'wget -qO- "http://localhost:9090/api/v1/query?query=container_memory_working_set_bytes{namespace=\"nsp-alpha-murror\"}"' | \
  jq -r '.data.result | length'
```

If this returns a number > 0, metrics are working!

### Option B: Verify ServiceMonitor Discovery (Debugging)

Check Prometheus logs for ServiceMonitor discovery:

```bash
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -c config-reloader --tail=50
```

### Option C: Use Application-Level Metrics Instead (Alternative)

Since the Murror API already exposes metrics at `/api/metrics`, we could add resource metrics to the application itself:

In your Murror API application (Node.js/NestJS), add:

```javascript
// Example using prom-client
const promClient = require('prom-client');
const register = new promClient.Register();

// Add default metrics (includes process CPU, memory, etc.)
promClient.collectDefaultMetrics({ register });

// Expose on /api/metrics endpoint (already configured)
```

This is actually MORE reliable than relying on kubelet/cadvisor!

## Fixing WARN/DEBUG Logs

The issue is likely at the application level. Check your Murror API log configuration:

```bash
# Check what's actually in the logs
kubectl logs -n nsp-alpha-murror murror-api-7d5c9b96b4-5stkg --tail=100

# Look for WARN or DEBUG entries
kubectl logs -n nsp-alpha-murror murror-api-7d5c9b96b4-5stkg --tail=1000 | grep -i "warn\|debug" | head -10
```

If no WARN/DEBUG logs appear, the application isn't logging them. Check:

1. Application log level configuration (environment variable like `LOG_LEVEL`)
2. Logger configuration in the app (winston/pino/bunyan config)

### To Add WARN/DEBUG Panels

Even if logs aren't appearing, we can add the panels:

```yaml
# Add to dashboard ConfigMap
{
  "title": "WARN Logs",
  "expr": "{namespace=\"$namespace\", app=\"murror-api\"} | json | severity=\"WARN\""
}

{
  "title": "DEBUG Logs",
  "expr": "{namespace=\"$namespace\", app=\"murror-api\"} | json | severity=\"DEBUG\""
}
```

## Files to Review

1. **Dashboard**: `/monitoring/clusters/sg3/murror-api-dashboard-configmap.yaml`
2. **Prometheus Config**: `/monitoring/clusters/sg3/values.yaml`
3. **Detailed Issues**: `/monitoring/clusters/sg3/MONITORING_ISSUES.md`

## Commands Reference

### Restart Components

```bash
# Restart Grafana
kubectl rollout restart deployment kube-prometheus-stack-grafana -n monitoring

# Reload Prometheus config
kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -c prometheus -- kill -HUP 1
```

### Check Status

```bash
# All monitoring pods
kubectl get pods -n monitoring

# ServiceMonitors
kubectl get servicemonitor -n monitoring

# Check labels
kubectl get servicemonitor kube-prometheus-stack-kube-state-metrics -n monitoring -o jsonpath='{.metadata.labels}'
```

## Summary

**Grafana**: ✅ Working
**Dashboard**: ✅ Deployed (but showing "No data")
**Metrics Collection**: ❌ Needs investigation (ServiceMonitors patched, waiting for scrape)
**Log Levels**: ❌ Needs application-level fix

**Recommended Next Action**: Wait 2-3 minutes for Prometheus to scrape, then check if metrics appear in Grafana dashboard.
