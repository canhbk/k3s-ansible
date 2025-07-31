# Node.js Monitoring Example

This is a complete example of a Node.js application with Prometheus monitoring integration.

## Features

- Express.js web server
- Prometheus metrics endpoint at `/metrics`
- Custom business metrics (orders, connections)
- Health check endpoint at `/health`
- Kubernetes deployment with ServiceMonitor

## Local Development

1. Install dependencies:
   ```bash
   npm install
   ```

2. Run the application:
   ```bash
   npm start
   ```

3. Test endpoints:
   ```bash
   # Health check
   curl http://localhost:3000/health
   
   # Metrics
   curl http://localhost:3000/metrics
   
   # API endpoints
   curl http://localhost:3000/api/users
   curl -X POST http://localhost:3000/api/orders -H "Content-Type: application/json" -d '{"paymentMethod":"credit_card"}'
   ```

## Building and Deploying

1. Build Docker image:
   ```bash
   docker build -t nodejs-monitoring-example:latest .
   ```

2. Test locally:
   ```bash
   docker run -p 3000:3000 nodejs-monitoring-example:latest
   ```

3. Deploy to Kubernetes:
   ```bash
   kubectl apply -f k8s-deployment.yaml
   ```

4. Verify deployment:
   ```bash
   kubectl get pods -n nodejs-example
   kubectl get svc -n nodejs-example
   kubectl get servicemonitor -n nodejs-example
   ```

## Metrics Exposed

### Default Metrics (from prom-client)
- `process_cpu_user_seconds_total`
- `process_cpu_system_seconds_total`
- `process_cpu_seconds_total`
- `process_resident_memory_bytes`
- `nodejs_eventloop_lag_seconds`
- `nodejs_heap_size_total_bytes`
- `nodejs_heap_size_used_bytes`
- `nodejs_external_memory_bytes`
- `nodejs_gc_duration_seconds`
- `nodejs_version_info`

### HTTP Metrics (from express-prom-bundle)
- `up` - Is the service up (1) or down (0)
- `http_request_duration_seconds` - HTTP request latencies

### Custom Business Metrics
- `http_request_duration_seconds` - Detailed request duration histogram
- `nodejs_active_connections` - Active connections gauge (http, websocket)
- `orders_processed_total` - Orders processed counter
- `database_connections_active` - Active database connections gauge

## Grafana Dashboard

Import the dashboard from `grafana-dashboard.json` or create panels with these queries:

### Request Rate
```promql
sum(rate(http_request_duration_seconds_count{job="nodejs-monitoring-example"}[5m])) by (method, route)
```

### 95th Percentile Response Time
```promql
histogram_quantile(0.95, 
  sum(rate(http_request_duration_seconds_bucket{job="nodejs-monitoring-example"}[5m])) by (le, method)
)
```

### Active Connections
```promql
sum(nodejs_active_connections{job="nodejs-monitoring-example"}) by (type)
```

### Order Success Rate
```promql
sum(rate(orders_processed_total{job="nodejs-monitoring-example"}[5m])) by (status)
```

### Memory Usage
```promql
process_resident_memory_bytes{job="nodejs-monitoring-example"} / 1024 / 1024
```

## Troubleshooting

1. **Metrics not showing in Prometheus**:
   - Check ServiceMonitor labels match Prometheus selector
   - Verify the service has the correct labels
   - Check Prometheus targets page

2. **High memory usage**:
   - Review metric cardinality
   - Check for memory leaks in custom metrics
   - Adjust Node.js heap size if needed

3. **Metrics endpoint timeout**:
   - Increase scrape timeout in ServiceMonitor
   - Check for blocking operations in metrics collection