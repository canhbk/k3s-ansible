# RabbitMQ Configuration Summary - SG3 Cluster (Murror Dev)

**Date**: 2025-12-03
**Cluster**: sg3 (rabbitmq.sg3.canhnv.com)

## Virtual Hosts Created

✅ `/` (default)
✅ `murror_dev` - Main development environment
✅ `murror_test` - Testing environment
✅ `murror-preview` - Preview environment

## Users Created

### 1. rabbitmq (Super Admin)
- **Username**: `rabbitmq`
- **Password**: `<PASSWORD_FROM_K8S_SECRET>`
- **Tags**: administrator
- **Permissions**: Full access to all vhosts

### 2. admin (Admin User)
- **Username**: `admin`
- **Password**: Stored in Kubernetes secret `rabbitmq-admin-credentials`
- **Tags**: administrator
- **Permissions**: Full access to all vhosts (/, murror_dev, murror_test, murror-preview)

**Get admin password**:
```bash
kubectl get secret rabbitmq-admin-credentials -n rabbitmq -o jsonpath='{.data.password}' | base64 -d
```

### 3. default_user_Gb8LE9ly6K9D7thXs9I (Auto-generated)
- **Username**: `default_user_Gb8LE9ly6K9D7thXs9I`
- **Password**: `<AUTO_GENERATED_PASSWORD>`
- **Tags**: administrator

## Exchanges Created

### murror_dev vhost:
- `murror.notifications` (direct)
- `murror.analytics` (topic)
- `murror.main` (topic)
- `murror.dlx` (direct) - Dead Letter Exchange
- `murror.article.response.direct` (direct)
- `murror.main.direct` (direct)
- `murror.ai.direct` (direct)
- `murror.connections.direct` (direct)
- `murror.insights.direct` (direct)

### murror-preview vhost:
- `murror.article.response.direct` (direct)
- `murror.dlx` (direct) - Dead Letter Exchange
- `murror.main.direct` (direct)
- `murror.ai.direct` (direct)
- `murror.connections.direct` (direct)
- `murror.insights.direct` (direct)

## Queues Created

### murror_dev vhost (12 queues):
1. **murror.background.queue** - Background tasks (TTL: 48h, Max: 200k)
2. **murror.main.queue** - Main processing (TTL: 24h, Max: 100k)
3. **murror.dead.queue** - Dead letter queue (TTL: 7 days)
4. **murror.notifications.queue** - Notifications (TTL: 1h, Max: 50k)
5. **murror.analytics.queue** - Analytics events (TTL: 24h, Max: 500k)
6. **murror.article.response.queue** - AI article responses (TTL: 24h, Max: 50k)
7. **murror.article.response.dlq** - Article response DLQ
8. **murror.ai.queue** - AI processing
9. **murror.connections.queue** - Connection events
10. **murror.connections.dlq** - Connections DLQ
11. **murror.insights.queue** - Insights processing (TTL: 24h, Max: 50k)
12. **murror.insights.dlq** - Insights DLQ

### murror-preview vhost (8 queues):
1. **murror.main.queue** - Main processing (TTL: 24h, Max: 100k)
2. **murror.ai.queue** - AI processing
3. **murror.connections.queue** - Connection events
4. **murror.connections.dlq** - Connections DLQ
5. **murror.insights.queue** - Insights processing (TTL: 24h, Max: 50k)
6. **murror.insights.dlq** - Insights DLQ
7. **murror.article.response.queue** - AI article responses (TTL: 24h, Max: 50k)
8. **murror.article.response.dlq** - Article response DLQ

## Bindings Created

All queues are properly bound to their respective exchanges with correct routing keys:

- Analytics: `analytics.*`, `event.*` → murror.analytics.queue
- Main: `conversation.*`, `user.*` → murror.main.queue
- Notifications: `notification` → murror.notifications.queue
- Dead letters: `*` → murror.dead.queue
- Direct bindings for AI, connections, insights, and article responses

## Access Information

### Management UI
- **URL**: https://rabbitmq.sg3.canhnv.com
- **Recommended User**: `admin` (get password from secret)
- **Alternative User**: `rabbitmq` / `<PASSWORD_FROM_K8S_SECRET>`

### Internal Service (from within cluster)

**AMQP Connection** (Port 5672):
```
amqp://admin:<password>@rabbitmq.rabbitmq.svc.cluster.local:5672/murror_dev
amqp://admin:<password>@rabbitmq.rabbitmq.svc.cluster.local:5672/murror-preview
amqp://admin:<password>@rabbitmq.rabbitmq.svc.cluster.local:5672/murror_test
```

**Management API** (Port 15672):
```
http://rabbitmq.rabbitmq.svc.cluster.local:15672
```

### External LoadBalancer
```bash
# AMQP: port 5672
# Management: port 15672
# Prometheus: port 15692

# Available IPs (live nodes as of 2026-07-24):
15.235.197.174, 15.235.197.175, 15.235.197.222
15.235.211.39, 15.235.211.111
```

## Connection Examples

### Node.js (amqplib)
```javascript
const amqp = require('amqplib');

const connection = await amqp.connect({
  protocol: 'amqp',
  hostname: 'rabbitmq.rabbitmq.svc.cluster.local',
  port: 5672,
  username: 'admin',
  password: process.env.RABBITMQ_PASSWORD,
  vhost: 'murror_dev'
});
```

### Python (pika)
```python
import pika
import os

credentials = pika.PlainCredentials('admin', os.environ['RABBITMQ_PASSWORD'])
parameters = pika.ConnectionParameters(
    host='rabbitmq.rabbitmq.svc.cluster.local',
    port=5672,
    virtual_host='murror_dev',
    credentials=credentials
)
connection = pika.BlockingConnection(parameters)
```

### Spring Boot (Java)
```yaml
spring:
  rabbitmq:
    host: rabbitmq.rabbitmq.svc.cluster.local
    port: 5672
    username: admin
    password: ${RABBITMQ_PASSWORD}
    virtual-host: murror_dev
```

## Verification Commands

```bash
# Switch to sg3 cluster
kubectl config use-context sg3

# List vhosts
kubectl exec rabbitmq-server-0 -n rabbitmq -- rabbitmqctl list_vhosts

# List queues in murror_dev
kubectl exec rabbitmq-server-0 -n rabbitmq -- rabbitmqctl list_queues -p murror_dev name messages

# List exchanges in murror_dev
kubectl exec rabbitmq-server-0 -n rabbitmq -- rabbitmqctl list_exchanges -p murror_dev name type

# List bindings in murror_dev
kubectl exec rabbitmq-server-0 -n rabbitmq -- rabbitmqctl list_bindings -p murror_dev

# Check cluster status
kubectl exec rabbitmq-server-0 -n rabbitmq -- rabbitmqctl cluster_status

# Get admin password
kubectl get secret rabbitmq-admin-credentials -n rabbitmq -o jsonpath='{.data.password}' | base64 -d
```

## Queue Configuration Details

| Queue | vhost | TTL | Max Length | DLX | DLQ Routing Key |
|-------|-------|-----|------------|-----|-----------------|
| murror.background.queue | murror_dev | 48h | 200,000 | murror.dlx | background.dead |
| murror.main.queue | murror_dev, murror-preview | 24h | 100,000 | murror.dlx | main.dead |
| murror.notifications.queue | murror_dev | 1h | 50,000 | murror.dlx | notifications.dead |
| murror.analytics.queue | murror_dev | 24h | 500,000 | murror.dlx | analytics.dead |
| murror.article.response.queue | murror_dev, murror-preview | 24h | 50,000 | murror.dlx | murror.article.response.dlq |
| murror.insights.queue | murror_dev, murror-preview | 24h | 50,000 | murror.dlx | murror.insights.dlq |
| murror.connections.queue | murror_dev, murror-preview | - | - | murror.dlx | murror.connections.dlq |
| murror.dead.queue | murror_dev | 7 days | - | - | - |

## Notes

- All queues use classic queue type
- Dead letter exchanges (DLX) configured for automatic retry/failure handling
- High-capacity analytics queue (500k messages) for high-throughput scenarios
- Short TTL on notifications queue (1h) for time-sensitive alerts
- All DLQ (dead letter queues) have no TTL or max length for permanent storage
- Cluster is running with 1 Longhorn replica per volume due to storage constraints

## Backup/Export

To export current definitions:
```bash
kubectl exec rabbitmq-server-0 -n rabbitmq -- rabbitmqctl export_definitions /var/lib/rabbitmq/definitions-backup.json
kubectl cp rabbitmq/rabbitmq-server-0:/var/lib/rabbitmq/definitions-backup.json ./rabbitmq-definitions-$(date +%Y%m%d).json
```

## Related Files

- Definitions file: `/var/lib/rabbitmq/definitions.json` (inside pod)
- Local backup: `/tmp/rabbitmq-definitions.json`
- Cluster config: `rabbitmq/clusters/sg3/rabbitmq-cluster.yaml`
- Ingress config: `rabbitmq/clusters/sg3/ingress.yaml`
