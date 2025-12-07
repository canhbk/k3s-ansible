# RabbitMQ Connection Information - sg3 Cluster

## Overview

This RabbitMQ cluster is configured with multiple virtual hosts for different environments and includes pre-configured queues, exchanges, and bindings for the Murror application.

## Quick Reference

### Admin User (Full Access)

**For murror_dev vhost:**
```
amqp://admin:MurrorAdmin2024!SecurePass@rabbitmq.rabbitmq.svc.cluster.local:5672/murror_dev
```

**For murror-preview vhost:**
```
amqp://admin:MurrorAdmin2024!SecurePass@rabbitmq.rabbitmq.svc.cluster.local:5672/murror-preview
```

**For murror_test vhost:**
```
amqp://admin:MurrorAdmin2024!SecurePass@rabbitmq.rabbitmq.svc.cluster.local:5672/murror_test
```

**For default vhost (/):**
```
amqp://admin:MurrorAdmin2024!SecurePass@rabbitmq.rabbitmq.svc.cluster.local:5672/
```

### Standard User (rabbitmq)

**For default vhost:**
```
amqp://rabbitmq:__REDACTED__@rabbitmq.rabbitmq.svc.cluster.local:5672/
```

### Application-Specific Users

#### murror-dev User (murror-ai application)

**For murror_dev vhost:**
```
amqp://murror-dev:HEozjwdtdExJLRKVukv2sNCFqQAniYd@rabbitmq.rabbitmq.svc.cluster.local:5672/murror_dev
```

- **Username**: `murror-dev`
- **Password**: `HEozjwdtdExJLRKVukv2sNCFqQAniYd`
- **Virtual Host**: `murror_dev`
- **Permissions**: Full access (configure/write/read: .*)
- **Tags**: monitoring
- **Purpose**: Dedicated user for murror-ai application
- **Namespace**: nsp-alpha-murror-ai

## Connection Parameters

| Parameter | Value |
|-----------|-------|
| **Host** | `rabbitmq.rabbitmq.svc.cluster.local` |
| **Port** | `5672` (AMQP) |
| **Admin Username** | `admin` |
| **Admin Password** | `MurrorAdmin2024!SecurePass` |
| **Standard Username** | `rabbitmq` |
| **Standard Password** | `__REDACTED__` |
| **murror-dev Username** | `murror-dev` (for murror-ai app) |
| **murror-dev Password** | `HEozjwdtdExJLRKVukv2sNCFqQAniYd` |

## Virtual Hosts

| VHost | Purpose | Default Queue Type |
|-------|---------|-------------------|
| `murror_dev` | Development environment | classic |
| `murror-preview` | Preview/staging environment | classic |
| `murror_test` | Testing environment | classic |
| `/` | Default/root vhost | classic |

## Configured Queues by VHost

### murror_dev Virtual Host

| Queue Name | Type | Max Length | TTL | Dead Letter Exchange |
|------------|------|------------|-----|---------------------|
| `murror.main.queue` | classic | 100,000 | 24h | murror.dlx |
| `murror.ai.queue` | classic | - | - | - |
| `murror.connections.queue` | classic | - | - | murror.dlx |
| `murror.insights.queue` | classic | 50,000 | 24h | murror.dlx |
| `murror.analytics.queue` | classic | 500,000 | 24h | murror.dlx |
| `murror.notifications.queue` | classic | 50,000 | 1h | murror.dlx |
| `murror.background.queue` | classic | 200,000 | 48h | murror.dlx |
| `murror.article.response.queue` | classic | 50,000 | 24h | murror.dlx |
| `murror.dead.queue` | classic | - | 7d | - |
| `murror.connections.dlq` | classic | - | - | - |
| `murror.insights.dlq` | classic | - | - | - |
| `murror.article.response.dlq` | classic | - | - | - |

### murror-preview Virtual Host

| Queue Name | Type | Max Length | TTL | Dead Letter Exchange |
|------------|------|------------|-----|---------------------|
| `murror.main.queue` | classic | 100,000 | 24h | murror.dlx |
| `murror.ai.queue` | classic | - | - | - |
| `murror.connections.queue` | classic | - | - | murror.dlx |
| `murror.insights.queue` | classic | 50,000 | 24h | murror.dlx |
| `murror.article.response.queue` | classic | 50,000 | 24h | murror.dlx |
| `murror.connections.dlq` | classic | - | - | - |
| `murror.insights.dlq` | classic | - | - | - |
| `murror.article.response.dlq` | classic | - | - | - |

## Configured Exchanges

### murror_dev Virtual Host

| Exchange Name | Type | Durable |
|---------------|------|---------|
| `murror.main` | topic | Yes |
| `murror.main.direct` | direct | Yes |
| `murror.ai.direct` | direct | Yes |
| `murror.connections.direct` | direct | Yes |
| `murror.insights.direct` | direct | Yes |
| `murror.analytics` | topic | Yes |
| `murror.notifications` | direct | Yes |
| `murror.article.response.direct` | direct | Yes |
| `murror.dlx` | direct | Yes (Dead Letter Exchange) |

### murror-preview Virtual Host

| Exchange Name | Type | Durable |
|---------------|------|---------|
| `murror.main.direct` | direct | Yes |
| `murror.ai.direct` | direct | Yes |
| `murror.connections.direct` | direct | Yes |
| `murror.insights.direct` | direct | Yes |
| `murror.article.response.direct` | direct | Yes |
| `murror.dlx` | direct | Yes (Dead Letter Exchange) |

## Key Bindings

### Analytics (murror_dev)
- `murror.analytics` → `murror.analytics.queue` (routing keys: `analytics.*`, `event.*`)

### Main Processing (murror_dev)
- `murror.main` → `murror.main.queue` (routing keys: `conversation.*`, `user.*`)
- `murror.main.direct` → `murror.main.queue` (routing key: `murror.main.queue`)

### Notifications (murror_dev)
- `murror.notifications` → `murror.notifications.queue` (routing key: `notification`)

### Dead Letter
- `murror.dlx` → `murror.dead.queue` (routing key: `*`)
- `murror.dlx` → specific DLQs (various routing keys)

## Management UI

- **External URL**: https://rabbitmq.sg3.canhnv.com
- **Internal URL**: http://rabbitmq.rabbitmq.svc.cluster.local:15672
- **Username**: `admin` or `rabbitmq`
- **Password**: Use respective passwords above

## Connection Methods

### Method 1: Use Kubernetes Secret (Recommended)

```bash
# Apply the secret to your namespace
kubectl apply -f rabbitmq/clusters/sg3/app-rabbitmq-secret.yaml -n your-namespace
```

Then in your deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: your-app
spec:
  template:
    spec:
      containers:
      - name: app
        image: your-app:latest
        envFrom:
        - secretRef:
            name: rabbitmq-connection
```

### Method 2: Direct Environment Variables

For **murror_dev** environment:
```yaml
env:
- name: RABBITMQ_URL
  value: "amqp://admin:MurrorAdmin2024!SecurePass@rabbitmq.rabbitmq.svc.cluster.local:5672/murror_dev"
```

For **murror-preview** environment:
```yaml
env:
- name: RABBITMQ_URL
  value: "amqp://admin:MurrorAdmin2024!SecurePass@rabbitmq.rabbitmq.svc.cluster.local:5672/murror-preview"
```

## Language-Specific Examples

### Python (pika) - Connect to murror_dev

```python
import pika
import os

# Using URL
connection = pika.BlockingConnection(
    pika.URLParameters('amqp://admin:MurrorAdmin2024!SecurePass@rabbitmq.rabbitmq.svc.cluster.local:5672/murror_dev')
)

# Or using connection parameters
credentials = pika.PlainCredentials('admin', 'MurrorAdmin2024!SecurePass')
parameters = pika.ConnectionParameters(
    host='rabbitmq.rabbitmq.svc.cluster.local',
    port=5672,
    virtual_host='murror_dev',
    credentials=credentials
)
connection = pika.BlockingConnection(parameters)

# Create channel and declare queue
channel = connection.channel()
channel.basic_publish(
    exchange='murror.main.direct',
    routing_key='murror.main.queue',
    body='Hello World'
)
```

### Node.js (amqplib) - Connect to murror_dev

```javascript
const amqp = require('amqplib');

// Using URL
const connection = await amqp.connect(
  'amqp://admin:MurrorAdmin2024!SecurePass@rabbitmq.rabbitmq.svc.cluster.local:5672/murror_dev'
);

// Create channel
const channel = await connection.createChannel();

// Publish to main queue
await channel.publish(
  'murror.main.direct',
  'murror.main.queue',
  Buffer.from('Hello World')
);
```

### Go (amqp091-go) - Connect to murror_dev

```go
import "github.com/rabbitmq/amqp091-go"

conn, err := amqp091.Dial("amqp://admin:MurrorAdmin2024!SecurePass@rabbitmq.rabbitmq.svc.cluster.local:5672/murror_dev")
if err != nil {
    log.Fatalf("Failed to connect: %v", err)
}
defer conn.Close()

ch, err := conn.Channel()
if err != nil {
    log.Fatalf("Failed to open channel: %v", err)
}
defer ch.Close()

// Publish message
err = ch.Publish(
    "murror.main.direct", // exchange
    "murror.main.queue",  // routing key
    false,                // mandatory
    false,                // immediate
    amqp091.Publishing{
        ContentType: "text/plain",
        Body:        []byte("Hello World"),
    })
```

## Testing Connection

### Test from within cluster

```bash
# Create test pod
kubectl run -it --rm rabbitmq-test --image=alpine --restart=Never -- sh

# Install rabbitmq tools
apk add --no-cache rabbitmq-c-utils

# Test connection to murror_dev vhost
amqp-declare-queue \
  --url="amqp://admin:MurrorAdmin2024!SecurePass@rabbitmq.rabbitmq.svc.cluster.local:5672/murror_dev" \
  --queue=test-queue

# Publish a test message
amqp-publish \
  --url="amqp://admin:MurrorAdmin2024!SecurePass@rabbitmq.rabbitmq.svc.cluster.local:5672/murror_dev" \
  --exchange=murror.main.direct \
  --routing-key=murror.main.queue \
  --body="Test message"
```

### Verify queues exist

```bash
# List all queues in murror_dev vhost
kubectl exec -n rabbitmq rabbitmq-server-0 -- rabbitmqctl list_queues -p murror_dev name messages consumers

# Check bindings
kubectl exec -n rabbitmq rabbitmq-server-0 -- rabbitmqctl list_bindings -p murror_dev

# Check exchanges
kubectl exec -n rabbitmq rabbitmq-server-0 -- rabbitmqctl list_exchanges -p murror_dev
```

## Retrieving Credentials

### Admin Credentials

```bash
# Username is: admin
# Password is: MurrorAdmin2024!SecurePass

# Or retrieve from secret (if stored)
kubectl get secret rabbitmq-admin-credentials -n rabbitmq \
  -o jsonpath='{.data.username}' | base64 -d && echo
```

### Standard User Credentials

```bash
# Get rabbitmq user credentials
kubectl get secret rabbitmq-credentials -n rabbitmq \
  -o jsonpath='{.data.username}' | base64 -d && echo
kubectl get secret rabbitmq-credentials -n rabbitmq \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

## User Permissions

### Admin user has full permissions on all vhosts:

```bash
kubectl exec -n rabbitmq rabbitmq-server-0 -- rabbitmqctl list_user_permissions admin
```

Output:
```
vhost           configure  write  read
murror-preview  .*         .*     .*
murror_dev      .*         .*     .*
murror_test     .*         .*     .*
/               .*         .*     .*
```

### murror-dev user permissions:

```bash
kubectl exec -n rabbitmq rabbitmq-server-0 -- rabbitmqctl list_user_permissions murror-dev
```

Output:
```
vhost       configure  write  read
murror_dev  .*         .*     .*
```

## High Availability Notes

- **3-node cluster** ensures high availability
- **Quorum queues** can be used for critical queues (currently using classic queues)
- **Dead Letter Exchanges** configured for error handling
- **Message TTL** configured per queue to prevent memory issues
- **Max length** configured to prevent unbounded growth

## Monitoring

### Check queue status

```bash
# Check message counts in murror_dev
kubectl exec -n rabbitmq rabbitmq-server-0 -- \
  rabbitmqctl list_queues -p murror_dev name messages messages_ready messages_unacknowledged

# Check consumer counts
kubectl exec -n rabbitmq rabbitmq-server-0 -- \
  rabbitmqctl list_queues -p murror_dev name consumers
```

### Prometheus Metrics

Metrics endpoint: `http://rabbitmq.rabbitmq.svc.cluster.local:15692/metrics`

## Troubleshooting

### Connection Refused

```bash
# Check if RabbitMQ pods are running
kubectl get pods -n rabbitmq

# Check service
kubectl get svc rabbitmq -n rabbitmq

# Test DNS resolution
kubectl run -it --rm test --image=busybox --restart=Never -- \
  nslookup rabbitmq.rabbitmq.svc.cluster.local
```

### Authentication Failed

```bash
# Verify admin user exists
kubectl exec -n rabbitmq rabbitmq-server-0 -- rabbitmqctl list_users

# Test authentication
kubectl exec -n rabbitmq rabbitmq-server-0 -- \
  rabbitmqctl authenticate_user admin 'MurrorAdmin2024!SecurePass'
```

### Vhost Not Found

```bash
# List all vhosts
kubectl exec -n rabbitmq rabbitmq-server-0 -- rabbitmqctl list_vhosts

# If vhost is missing, create it
kubectl exec -n rabbitmq rabbitmq-server-0 -- \
  rabbitmqctl add_vhost murror_dev

# Grant permissions
kubectl exec -n rabbitmq rabbitmq-server-0 -- \
  rabbitmqctl set_permissions -p murror_dev admin ".*" ".*" ".*"
```

### View Logs

```bash
# View RabbitMQ logs
kubectl logs -n rabbitmq rabbitmq-server-0 -f

# View cluster status
kubectl exec -n rabbitmq rabbitmq-server-0 -- rabbitmqctl cluster_status
```

## Security Best Practices

1. **Use the admin user only for management** - Create app-specific users for production
2. **Store credentials in Kubernetes Secrets** - Never hardcode in application code
3. **Use TLS** - Enable TLS for production connections
4. **Limit permissions** - Grant minimal required permissions per application
5. **Monitor access** - Use RabbitMQ management UI or Prometheus to track connections

## Configuration Backup

The current configuration is exported and can be re-imported:

```bash
# Export current definitions
kubectl exec -n rabbitmq rabbitmq-server-0 -- \
  rabbitmqctl export_definitions /tmp/definitions.json

# Copy to local machine
kubectl cp rabbitmq/rabbitmq-server-0:/tmp/definitions.json \
  ./rabbitmq-definitions-$(date +%Y%m%d).json
```

## Recent Changes

### 2025-12-04 (Latest)
- **Fixed murror-api RabbitMQ connectivity**: Updated murror-api-secret with correct murror-dev credentials
  - Previous: Used `default_user` with no vhost access (6+ days of failures, 81 pod restarts)
  - Current: Uses `murror-dev` user with `murror_dev` vhost
  - Resolution: Updated secret RABBITMQ_URL and recreated incompatible queues
  - Status: Pod now Running and Ready (1/1)
  - Used by: murror-api deployment in nsp-alpha-murror namespace

- **Added murror-dev user**: Created dedicated user for murror-ai and murror-api applications
  - Username: `murror-dev`
  - Virtual host: `murror_dev`
  - Permissions: Full access on murror_dev vhost
  - Tags: monitoring
  - Used by:
    - murror-ai deployment in nsp-alpha-murror-ai namespace
    - murror-api deployment in nsp-alpha-murror namespace

## Last Updated

2025-12-04 - Fixed murror-api connectivity and updated documentation
2025-12-04 - Added murror-dev application user
2025-12-03 - RabbitMQ 4.0.9 cluster with murror_dev, murror-preview, murror_test vhosts
