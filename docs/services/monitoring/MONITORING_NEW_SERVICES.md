# Monitoring New Services in K3s Clusters

This guide explains how to add Prometheus monitoring to your applications deployed in K3s clusters.

## Table of Contents

- [Overview](#overview)
- [Node.js Backend Monitoring](#nodejs-backend-monitoring)
- [Python Flask Backend Monitoring](#python-flask-backend-monitoring)
- [Kubernetes Configuration](#kubernetes-configuration)
- [Grafana Dashboard Setup](#grafana-dashboard-setup)
- [Best Practices](#best-practices)

## Overview

Prometheus discovers and scrapes metrics from services using two methods:

1. **ServiceMonitor CRDs** (Recommended)
2. **Pod Annotations** (Simple but limited)

## Node.js Backend Monitoring

### 1. Install Prometheus Client

```bash
npm install prom-client express-prom-bundle
```

### 2. Add Metrics to Your Application

```javascript
// app.js or server.js
const express = require('express');
const promBundle = require('express-prom-bundle');
const promClient = require('prom-client');

const app = express();

// Add basic prometheus middleware
const metricsMiddleware = promBundle({
  includeMethod: true,
  includePath: true,
  includeStatusCode: true,
  includeUp: true,
  customLabels: {
    project_name: 'my-nodejs-app',
    environment: process.env.NODE_ENV || 'development'
  },
  promClient: {
    collectDefaultMetrics: {
      timeout: 10000
    }
  }
});

app.use(metricsMiddleware);

// Custom metrics examples
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5]
});

const activeConnections = new promClient.Gauge({
  name: 'nodejs_active_connections',
  help: 'Number of active connections'
});

const businessMetric = new promClient.Counter({
  name: 'business_orders_total',
  help: 'Total number of orders processed',
  labelNames: ['status', 'payment_method']
});

// Middleware to track request duration
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestDuration.observe({
      method: req.method,
      route: req.route?.path || 'unknown',
      status_code: res.statusCode
    }, duration);
  });
  next();
});

// Your application routes
app.get('/api/orders', (req, res) => {
  // Business logic...
  businessMetric.inc({ status: 'success', payment_method: 'credit_card' });
  res.json({ success: true });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Metrics available at http://localhost:${PORT}/metrics`);
});
```

### 3. Dockerfile Configuration

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000 9090
CMD ["node", "app.js"]
```

## Python Flask Backend Monitoring

### 1. Install Prometheus Client

```bash
pip install prometheus-client flask prometheus-flask-exporter
```

### 2. Add Metrics to Your Application

```python
# app.py
from flask import Flask, jsonify
from prometheus_client import Counter, Histogram, Gauge, generate_latest
from prometheus_flask_exporter import PrometheusMetrics
import time
import os

app = Flask(__name__)

# Initialize PrometheusMetrics
metrics = PrometheusMetrics(app)

# Static labels for all metrics
metrics.info('app_info', 'Application info', version='1.0.0',
             environment=os.getenv('ENVIRONMENT', 'development'))

# Custom metrics
request_duration = Histogram(
    'flask_request_duration_seconds',
    'Flask request duration',
    ['method', 'endpoint', 'status']
)

active_users = Gauge(
    'flask_active_users',
    'Number of active users'
)

business_transactions = Counter(
    'business_transactions_total',
    'Total business transactions',
    ['type', 'status']
)

error_counter = Counter(
    'flask_errors_total',
    'Total number of errors',
    ['error_type']
)

# Decorator for timing requests
def track_request_time(f):
    def decorated_function(*args, **kwargs):
        start_time = time.time()
        try:
            result = f(*args, **kwargs)
            status = 'success'
            return result
        except Exception as e:
            status = 'error'
            error_counter.labels(error_type=type(e).__name__).inc()
            raise
        finally:
            duration = time.time() - start_time
            request_duration.labels(
                method=request.method,
                endpoint=request.endpoint or 'unknown',
                status=status
            ).observe(duration)
    decorated_function.__name__ = f.__name__
    return decorated_function

# Application routes
@app.route('/api/users')
@track_request_time
def get_users():
    # Simulate active users
    active_users.set(42)
    return jsonify({'users': ['user1', 'user2']})

@app.route('/api/transaction', methods=['POST'])
@track_request_time
def create_transaction():
    # Business logic here
    business_transactions.labels(type='purchase', status='completed').inc()
    return jsonify({'status': 'success', 'transaction_id': '12345'})

@app.route('/health')
def health_check():
    return jsonify({'status': 'healthy'})

# Custom metrics endpoint (if not using default /metrics)
@app.route('/custom-metrics')
def custom_metrics():
    return generate_latest()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

### 3. Using Gunicorn with Prometheus

```python
# gunicorn_config.py
from prometheus_client import multiprocess
from prometheus_client import CollectorRegistry, generate_latest

def worker_exit(server, worker):
    multiprocess.mark_process_dead(worker.pid)

def child_exit(server, worker):
    multiprocess.mark_process_dead(worker.pid)

# Environment variable required for multiprocess mode
import os
os.environ['prometheus_multiproc_dir'] = '/tmp/prometheus_multiproc_dir'
```

Run with:

```bash
gunicorn -c gunicorn_config.py -w 4 app:app
```

## Kubernetes Configuration

### Method 1: ServiceMonitor (Recommended)

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-nodejs-app
  namespace: my-app
  labels:
    app: my-nodejs-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-nodejs-app
  template:
    metadata:
      labels:
        app: my-nodejs-app
    spec:
      containers:
      - name: app
        image: my-nodejs-app:latest
        ports:
        - name: http
          containerPort: 3000
        - name: metrics
          containerPort: 3000  # Same port for Node.js example
        env:
        - name: NODE_ENV
          value: "production"
        livenessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: my-nodejs-app
  namespace: my-app
  labels:
    app: my-nodejs-app
spec:
  selector:
    app: my-nodejs-app
  ports:
  - name: http
    port: 80
    targetPort: http
  - name: metrics
    port: 3000
    targetPort: metrics
---
# ServiceMonitor for Prometheus to discover this service
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-nodejs-app
  namespace: my-app
  labels:
    app: my-nodejs-app
    release: kube-prometheus-stack  # Important: must match Prometheus serviceMonitorSelector
spec:
  selector:
    matchLabels:
      app: my-nodejs-app
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
    scheme: http
    relabelings:
    - sourceLabels: [__meta_kubernetes_pod_name]
      targetLabel: pod
    - sourceLabels: [__meta_kubernetes_namespace]
      targetLabel: namespace
```

### Method 2: Pod Annotations (Simple)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-flask-app
  namespace: my-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-flask-app
  template:
    metadata:
      labels:
        app: my-flask-app
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "5000"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: app
        image: my-flask-app:latest
        ports:
        - containerPort: 5000
          name: http
        env:
        - name: ENVIRONMENT
          value: "production"
```

### Verify Service Discovery

After deployment, check if Prometheus discovered your service:

```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Open browser to http://localhost:9090
# Go to Status -> Targets
# Look for your service
```

## Grafana Dashboard Setup

### 1. Create a Custom Dashboard

1. Access Grafana at <https://grafana.{cluster}.k3s.canhnv.com>
2. Click "+" → "Dashboard" → "Add new panel"

### 2. Example Queries

#### Request Rate

```promql
sum(rate(http_requests_total{job="my-nodejs-app"}[5m])) by (method, status_code)
```

#### Request Duration (95th percentile)

```promql
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket{job="my-nodejs-app"}[5m])) by (le, method)
)
```

#### Error Rate

```promql
sum(rate(flask_errors_total{job="my-flask-app"}[5m])) by (error_type)
```

#### Active Connections/Users

```promql
avg(nodejs_active_connections{job="my-nodejs-app"})
```

#### Business Metrics

```promql
sum(rate(business_transactions_total[1h])) by (type, status)
```

### 3. Save Dashboard as ConfigMap

Export your dashboard JSON and create a ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-app-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  my-app-dashboard.json: |
    {
      "dashboard": {
        "title": "My Application Metrics",
        "panels": [
          {
            "title": "Request Rate",
            "targets": [{
              "expr": "sum(rate(http_requests_total{job=\"my-nodejs-app\"}[5m])) by (method, status_code)"
            }]
          }
        ]
      }
    }
```

## Best Practices

### 1. Metric Naming Conventions

- Use lowercase with underscores
- Include unit in the name (e.g., `_seconds`, `_bytes`)
- End counters with `_total`
- Be consistent across services

### 2. Essential Metrics to Track

- **RED Method**: Rate, Errors, Duration
- **USE Method**: Utilization, Saturation, Errors
- **Business Metrics**: Specific to your application

### 3. Label Best Practices

- Keep cardinality low (avoid unique IDs)
- Use consistent label names
- Include: `environment`, `version`, `region`
- Avoid: `user_id`, `session_id`, `timestamp`

### 4. Resource Considerations

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "50m"
  limits:
    memory: "128Mi"
    cpu: "100m"
```

### 5. Security

- Don't expose sensitive data in metrics
- Use separate port for metrics if needed
- Consider authentication for metrics endpoint

## Common Issues and Solutions

### Metrics Not Appearing

1. Check ServiceMonitor labels match Prometheus selector
2. Verify metrics endpoint is accessible
3. Check namespace permissions
4. Review Prometheus logs

### High Cardinality

```promql
# Check cardinality
count(count by (__name__)({__name__=~".+"}))
```

### Testing Locally

```bash
# Test metrics endpoint
curl http://localhost:3000/metrics

# Test with Prometheus locally
docker run -p 9090:9090 -v prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus
```

## Example Full Implementation

See the `/monitoring/examples/` directory for complete examples:

- `nodejs-example/` - Full Node.js application with monitoring
- `flask-example/` - Full Flask application with monitoring
- `dashboards/` - Pre-built Grafana dashboards

## Next Steps

1. Deploy your application with metrics
2. Verify in Prometheus targets
3. Import or create Grafana dashboards
4. Set up alerts for critical metrics
5. Monitor and iterate on your metrics
