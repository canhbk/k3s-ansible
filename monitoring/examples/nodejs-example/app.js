const express = require('express');
const promBundle = require('express-prom-bundle');
const promClient = require('prom-client');

const app = express();
const PORT = process.env.PORT || 3000;

// Add the prometheus middleware to all routes
const metricsMiddleware = promBundle({
  includeMethod: true,
  includePath: true,
  includeStatusCode: true,
  includeUp: true,
  customLabels: {
    project_name: 'nodejs-monitoring-example',
    environment: process.env.NODE_ENV || 'development'
  },
  promClient: {
    collectDefaultMetrics: {
      timeout: 10000
    }
  }
});

// Add middleware
app.use(express.json());
app.use(metricsMiddleware);

// Custom metrics
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5]
});

const activeConnections = new promClient.Gauge({
  name: 'nodejs_active_connections',
  help: 'Number of active connections',
  labelNames: ['type']
});

const ordersProcessed = new promClient.Counter({
  name: 'orders_processed_total',
  help: 'Total number of orders processed',
  labelNames: ['status', 'payment_method']
});

const databaseConnections = new promClient.Gauge({
  name: 'database_connections_active',
  help: 'Number of active database connections'
});

// Set initial values
activeConnections.set({ type: 'websocket' }, 0);
activeConnections.set({ type: 'http' }, 0);
databaseConnections.set(5); // Simulated

// Track request duration middleware
app.use((req, res, next) => {
  const start = Date.now();

  // Increment active connections
  activeConnections.inc({ type: 'http' });

  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestDuration.observe({
      method: req.method,
      route: req.route?.path || req.path || 'unknown',
      status_code: res.statusCode
    }, duration);

    // Decrement active connections
    activeConnections.dec({ type: 'http' });
  });

  next();
});

// Routes
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    uptime: process.uptime(),
    timestamp: new Date().toISOString()
  });
});

app.get('/api/users', (req, res) => {
  // Simulate some processing time
  setTimeout(() => {
    res.json({
      users: [
        { id: 1, name: 'John Doe' },
        { id: 2, name: 'Jane Smith' }
      ]
    });
  }, Math.random() * 100);
});

app.post('/api/orders', (req, res) => {
  // Simulate order processing
  const paymentMethod = req.body.paymentMethod || 'credit_card';
  const success = Math.random() > 0.1; // 90% success rate

  if (success) {
    ordersProcessed.inc({ status: 'success', payment_method: paymentMethod });
    res.json({
      status: 'success',
      orderId: Math.random().toString(36).substring(7),
      message: 'Order processed successfully'
    });
  } else {
    ordersProcessed.inc({ status: 'failed', payment_method: paymentMethod });
    res.status(400).json({
      status: 'failed',
      message: 'Payment processing failed'
    });
  }
});

app.get('/api/status', (req, res) => {
  res.json({
    activeConnections: {
      http: activeConnections.get({ type: 'http' }),
      websocket: activeConnections.get({ type: 'websocket' })
    },
    databaseConnections: databaseConnections.get(),
    uptime: process.uptime()
  });
});

// Simulate some background activity
setInterval(() => {
  // Randomly adjust database connections
  databaseConnections.set(Math.floor(Math.random() * 10) + 1);

  // Simulate websocket connections
  activeConnections.set({ type: 'websocket' }, Math.floor(Math.random() * 50));
}, 5000);

// Error handling
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Metrics available at http://localhost:${PORT}/metrics`);
  console.log(`Health check at http://localhost:${PORT}/health`);
});
