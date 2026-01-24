# Monitoring Issues on SG3 Cluster - December 8, 2025

## Summary

While adding CPU, RAM, and disk monitoring to the Murror API dashboard, we discovered two main issues:

### Issue 1: Container Resource Metrics Not Available

**Problem**: The Prometheus queries for CPU, RAM, and disk metrics (from cadvisor/kubelet) return "No data"

**Root Cause**: Service Monitor selector mismatch
- Prometheus was configured to scrape ServiceMonitors with label: `prometheus: kube-prometheus-stack`
- But most built-in ServiceMonitors have label: `prometheus: kube-prometheus`
- This prevented Prometheus from discovering and scraping kube-state-metrics and kubelet/cadvisor metrics

**Fix Applied**:
- Updated `/monitoring/clusters/sg3/values.yaml` line 52
- Changed from `prometheus: kube-prometheus-stack` to `prometheus: kube-prometheus`
- Ran `helm upgrade` to apply the change
- Prometheus pod restarted successfully

**Current Status**:
- Configuration updated but metrics still not appearing after reload
- May require additional investigation into:
  - Whether kubelet ServiceMonitor has correct configuration
  - Whether kubelet/cadvisor endpoints are accessible
  - Whether metric relabeling rules are dropping required metrics

**Next Steps**:
1. Verify kubelet ServiceMonitor is now being discovered by Prometheus
2. Check Prometheus targets page for kubelet/cadvisor scrape status
3. Review metricRelabelings in kubelet ServiceMonitor (found dropping rules for some CPU metrics)
4. Consider enabling all container metrics or adjusting relabel rules

### Issue 2: WARN and DEBUG Logs Not Visible

**Problem**: User reports not seeing WARN and DEBUG level logs in Grafana dashboard

**Current Dashboard Configuration**:
- **Live Logs panel**: Shows ALL logs without severity filtering: `{namespace="$namespace", app="murror-api"}`
- **Error Logs Only panel**: Filters to ERROR severity: `{namespace="$namespace", app="murror-api"} | json | severity="ERROR"`

**Possible Causes**:
1. **Application not logging at those levels**: The Murror API application might not be configured to log WARN/DEBUG
2. **Promtail not collecting**: Promtail configuration might be filtering out certain log levels
3. **Loki retention**: Logs might have been rotated out (current retention: 15 days)

**Next Steps**:
1. Check Murror API application log level configuration (should be in environment variables or config)
2. Verify Promtail is collecting all log levels from the pods
3. Query Loki directly to see what severity levels are being stored
4. Add dedicated panels for WARN and DEBUG logs to the dashboard

### Issue 3: Grafana CrashLoopBackOff After Helm Upgrade

**Problem**: Grafana pods stuck in CrashLoopBackOff after running helm upgrade

**Root Cause**: PVC multi-attach conflict
- Old Grafana pod still had PVC mounted
- New Grafana pod couldn't attach the same RWO PVC
- After deleting old pod, new pod has different issue (needs investigation)

**Status**: Currently unresolved - Grafana may need manual intervention

**Next Steps**:
1. Check Grafana pod logs: `kubectl logs kube-prometheus-stack-grafana-xxxx -c grafana -n monitoring`
2. May need to rollback Grafana or fix underlying issue
3. Check if dashboard ConfigMaps are causing issues

## Recommended Actions

### Immediate (High Priority)

1. **Fix Grafana** - Get Grafana back online:
   ```bash
   kubectl logs -n monitoring -l app.kubernetes.io/name=grafana --tail=50
   kubectl describe pod -n monitoring -l app.kubernetes.io/name=grafana
   ```

2. **Add WARN/DEBUG log panels** - Update dashboard to explicitly show WARN and DEBUG:
   ```logql
   # WARN logs
   {namespace="$namespace", app="murror-api"} | json | severity="WARN"

   # DEBUG logs
   {namespace="$namespace", app="murror-api"} | json | severity="DEBUG"
   ```

### Short Term (Next 24 Hours)

3. **Debug Prometheus metrics collection**:
   ```bash
   # Check if kubelet is being scraped
   kubectl port-forward -n monitoring prometheus-kube-prometheus-stack-prometheus-0 9090:9090
   # Open browser to http://localhost:9090/targets
   # Look for kubelet and kube-state-metrics targets
   ```

4. **Alternative: Use node-level metrics** - If container metrics aren't available, use node metrics as alternative:
   ```promql
   # Node CPU usage
   rate(node_cpu_seconds_total{mode!="idle"}[5m])

   # Node memory
   node_memory_Active_bytes
   ```

### Medium Term (This Week)

5. **Review and fix kubelet ServiceMonitor metricRelabelings** - The kubelet ServiceMonitor has rules dropping some CPU metrics:
   ```yaml
   metricRelabelings:
   - action: drop
     regex: container_cpu_(cfs_throttled_seconds_total|load_average_10s|system_seconds_total|user_seconds_total)
     sourceLabels:
     - __name__
   ```
   Consider if these dropped metrics are needed for the dashboard.

6. **Test with a minimal dashboard** - Create a simple test dashboard with basic queries to verify metrics are flowing

## Files Modified

1. `/Users/canhnv/development/canhnv/k3s-ansible/monitoring/clusters/sg3/values.yaml`
   - Line 52: Changed serviceMonitorSelector from `kube-prometheus-stack` to `kube-prometheus`

2. `/Users/canhnv/development/canhnv/k3s-ansible/monitoring/clusters/sg3/murror-api-dashboard-configmap.yaml`
   - Added 6 new panels for CPU, Memory, and Disk monitoring
   - Reorganized layout into 5 rows
   - Currently deployed but showing "No data" due to metrics issue

## Backup Locations

- Dashboard backup: `/tmp/backup-murror-api-dashboard.yaml`
- Values.yaml: Should be in git history before our changes

## Contact for Follow-up

The monitoring stack is complex with multiple interdependent components:
- Prometheus Operator (manages Prometheus config)
- Prometheus (scrapes metrics)
- ServiceMonitors (define scrape targets)
- kube-state-metrics (exposes Kubernetes metrics)
- kubelet/cadvisor (exposes container metrics)
- node-exporter (exposes node metrics)
- Loki (logs aggregation)
- Promtail (log collection)
- Grafana (visualization)

Each component needs to be working and configured correctly for the full monitoring stack to function.

---

*Last Updated: 2025-12-08 by Claude Code*
