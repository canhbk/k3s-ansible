# Supabase Monitoring with Prometheus

This guide explains how to monitor your Supabase project using Prometheus and Grafana.

## Prerequisites

- Supabase project with service role JWT
- Prometheus/VictoriaMetrics running in your K3s cluster
- Grafana for visualization

## Setup Steps

### 1. Get Your Service Role JWT

1. Go to your Supabase Dashboard
2. Navigate to Settings > API
3. Copy the `service_role` secret key (JWT)

### 2. Deploy Prometheus Scrape Configuration

1. Update the secret with your JWT:

   ```bash
   kubectl create secret generic supabase-metrics-auth \
     --from-literal=service-role-jwt="<your-jwt>" \
     -n monitoring
   ```

2. Apply the scrape configuration:

   ```bash
   kubectl apply -f monitoring/examples/supabase-scrapeconfig.yaml
   ```

### 3. Import Grafana Dashboard

1. Access Grafana UI
2. Go to Dashboards > Import
3. Upload `monitoring/examples/supabase-grafana-dashboard.json`
4. Select your Prometheus data source

### 4. Deploy Alert Rules

```bash
kubectl apply -f monitoring/examples/supabase-alert-rules.yaml
```

## Available Metrics

### Database Metrics

- `cpu_usage` - Database CPU utilization
- `ram_usage` - Database memory utilization
- `active_connections` - Current active database connections
- `replication_slots_max_lag_bytes` - Replication lag in bytes

### API Metrics

- Request counts by method (GET, POST, PATCH, PUT)
- Ingress/Egress data volumes
- Response times and latencies

### System Metrics (Node Exporter)

- `node_memory_*` - Memory statistics
- `node_disk_*` - Disk I/O metrics
- `node_cpu_*` - CPU statistics

### PostgREST Metrics (v12.2+)

- `pgrst_db_pool_timeouts_total` - Connection pool timeout counter
- Server timing metrics in headers

## Troubleshooting

### Test Metrics Access

```bash
curl https://<project-id>.supabase.co/customer/v1/privileged/metrics \
  --user 'service_role:<service-role-jwt>'
```

### Common Issues

1. **401 Unauthorized**: Check your service role JWT
2. **No data in Grafana**: Verify Prometheus is scraping successfully
3. **High cardinality**: Limit labels in scrape config

## Advanced Configuration

### Custom Queries

Example PromQL queries for Supabase metrics:

```promql
# Cache hit rate
sum(rate(pg_stat_database_blks_hit[5m])) /
sum(rate(pg_stat_database_blks_hit[5m]) + rate(pg_stat_database_blks_read[5m])) * 100

# Replication lag in seconds
replication_slots_max_lag_bytes / 1024 / 1024 / 16  # Assuming 16MB/s WAL generation

# API request rate by method
sum by (method) (rate(api_requests_total[5m]))
```

### Integration with Existing Monitoring

The Supabase metrics can be integrated with your existing Prometheus stack:

1. Add the scrape config to your existing Prometheus configuration
2. Use the same alertmanager for notifications
3. Combine with other application metrics in dashboards

## Security Considerations

- Store service role JWT as Kubernetes secret
- Limit access to monitoring namespace
- Use RBAC to control who can view metrics
- Rotate service role JWT periodically

## References

- [Supabase Metrics Documentation](https://supabase.com/docs/guides/telemetry/metrics)
- [Prometheus Configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)
- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/best-practices/)
