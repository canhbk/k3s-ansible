# RabbitMQ on Dev Cluster

## Overview

RabbitMQ is deployed on the dev cluster to provide message broker capabilities for applications requiring asynchronous messaging, task queues, and pub/sub patterns.

## Deployment Information

- **Namespace**: `rabbitmq`
- **Deployment Method**: StatefulSet (custom manifests)
- **Image**: `rabbitmq:3.13-management`
- **Replicas**: 1 (single instance)
- **Storage**: 2Gi persistent volume using `local-path` storage class
- **Node Assignment**: `vps12-h2cloud-vn`

## Access Information

### Internal Access (Within Cluster)

**AMQP Connection** (for applications):

**Default Admin User**:
```
amqp://admin:***@rabbitmq.rabbitmq.svc.cluster.local:5672/
```

**Murror Dev User (murror_dev vhost)**:
```
amqp://murror-dev:***@rabbitmq.rabbitmq.svc.cluster.local:5672/murror_dev
```

**Murror Preview User (murror-preview vhost)**:
```
amqp://murror-preview:***@rabbitmq.rabbitmq.svc.cluster.local:5672/murror-preview
```

**Connection Details**:
- Host: `rabbitmq.rabbitmq.svc.cluster.local`
- AMQP Port: `5672`
- Management Port: `15672`

**Available Users**:
| Username | Password | Tags | Virtual Hosts |
|----------|----------|------|---------------|
| `admin` | `***` | administrator | All (default: `/`) |
| `murror-dev` | `***` | administrator | `murror_dev` |
| `murror-preview` | `***` | (none) | `murror-preview` |

**Available Virtual Hosts**:
- `/` (default)
- `murror_dev` (for murror-dev user)
- `murror_test`
- `murror-preview`

### External Access

**Management Dashboard**:
- URL: `https://dev.rabbitmq.ambercare.app`
- Username: `admin`
- Password: `***`
- TLS: Enabled via cert-manager with Let's Encrypt

## Configuration

### Credentials

Credentials are stored in Kubernetes secret:
```bash
kubectl get secret -n rabbitmq rabbitmq-secret -o jsonpath='{.data.username}' | base64 -d
kubectl get secret -n rabbitmq rabbitmq-secret -o jsonpath='{.data.password}' | base64 -d
```

### Services

| Service Name | Type | Ports | Purpose |
|--------------|------|-------|---------|
| `rabbitmq` | ClusterIP | 5672, 15672 | Main service endpoint |

### Ingress

The RabbitMQ Management UI is exposed via Traefik Ingress:
- File: `rabbitmq/clusters/dev/rabbitmq-ingress.yaml`
- Host: `dev.rabbitmq.ambercare.app`
- TLS: Managed by cert-manager using `ambercare-app` ClusterIssuer
- Certificate Secret: `rabbitmq-dev-tls`

## Usage Examples

### Application Connection

**Node.js** (using amqplib):

*With admin user (default vhost)*:
```javascript
const amqp = require('amqplib');

const connection = await amqp.connect(
  'amqp://admin:***@rabbitmq.rabbitmq.svc.cluster.local:5672/'
);
const channel = await connection.createChannel();
```

*With murror-dev user (murror_dev vhost)*:
```javascript
const amqp = require('amqplib');

const connection = await amqp.connect(
  'amqp://murror-dev:***@rabbitmq.rabbitmq.svc.cluster.local:5672/murror_dev'
);
const channel = await connection.createChannel();
```

*With murror-preview user (murror-preview vhost)*:
```javascript
const amqp = require('amqplib');

const connection = await amqp.connect(
  'amqp://murror-preview:***@rabbitmq.rabbitmq.svc.cluster.local:5672/murror-preview'
);
const channel = await connection.createChannel();
```

**Python** (using pika):

*With admin user (default vhost)*:
```python
import pika

credentials = pika.PlainCredentials('admin', '***')
parameters = pika.ConnectionParameters(
    'rabbitmq.rabbitmq.svc.cluster.local',
    5672,
    '/',
    credentials
)
connection = pika.BlockingConnection(parameters)
channel = connection.channel()
```

*With murror-dev user (murror_dev vhost)*:
```python
import pika

credentials = pika.PlainCredentials('murror-dev', '***')
parameters = pika.ConnectionParameters(
    'rabbitmq.rabbitmq.svc.cluster.local',
    5672,
    'murror_dev',
    credentials
)
connection = pika.BlockingConnection(parameters)
channel = connection.channel()
```

*With murror-preview user (murror-preview vhost)*:
```python
import pika

credentials = pika.PlainCredentials('murror-preview', '***')
parameters = pika.ConnectionParameters(
    'rabbitmq.rabbitmq.svc.cluster.local',
    5672,
    'murror-preview',
    credentials
)
connection = pika.BlockingConnection(parameters)
channel = connection.channel()
```

**Environment Variables**:

*For admin user (default vhost)*:
```bash
export RABBITMQ_URL="amqp://admin:***@rabbitmq.rabbitmq.svc.cluster.local:5672/"
export RABBITMQ_HOST=rabbitmq.rabbitmq.svc.cluster.local
export RABBITMQ_PORT=5672
export RABBITMQ_USERNAME=admin
export RABBITMQ_PASSWORD=***
export RABBITMQ_VHOST=/
```

*For murror-dev user (murror_dev vhost)*:
```bash
export RABBITMQ_URL="amqp://murror-dev:***@rabbitmq.rabbitmq.svc.cluster.local:5672/murror_dev"
export RABBITMQ_HOST=rabbitmq.rabbitmq.svc.cluster.local
export RABBITMQ_PORT=5672
export RABBITMQ_USERNAME=murror-dev
export RABBITMQ_PASSWORD=***
export RABBITMQ_VHOST=murror_dev
```

*For murror-preview user (murror-preview vhost)*:
```bash
export RABBITMQ_URL="amqp://murror-preview:***@rabbitmq.rabbitmq.svc.cluster.local:5672/murror-preview"
export RABBITMQ_HOST=rabbitmq.rabbitmq.svc.cluster.local
export RABBITMQ_PORT=5672
export RABBITMQ_USERNAME=murror-preview
export RABBITMQ_PASSWORD=***
export RABBITMQ_VHOST=murror-preview
```

### Management Operations

**Check cluster status**:
```bash
kubectl exec -it rabbitmq-0 -n rabbitmq -- rabbitmq-diagnostics status
```

**List users**:
```bash
kubectl exec -it rabbitmq-0 -n rabbitmq -- rabbitmqctl list_users
```

**List queues**:
```bash
kubectl exec -it rabbitmq-0 -n rabbitmq -- rabbitmqctl list_queues
```

**Create new user**:
```bash
kubectl exec -it rabbitmq-0 -n rabbitmq -- rabbitmqctl add_user myuser mypassword
kubectl exec -it rabbitmq-0 -n rabbitmq -- rabbitmqctl set_permissions -p / myuser ".*" ".*" ".*"
```

## Monitoring

### Management UI

Access the management dashboard at `https://dev.rabbitmq.ambercare.app` to view:
- Queue statistics
- Connection details
- Message rates
- Memory and disk usage
- Cluster overview

### CLI Monitoring

**Check queue status**:
```bash
kubectl exec -it rabbitmq-0 -n rabbitmq -- rabbitmqctl list_queues name messages consumers
```

**Monitor memory usage**:
```bash
kubectl exec -it rabbitmq-0 -n rabbitmq -- rabbitmq-diagnostics memory_breakdown
```

**Check connections**:
```bash
kubectl exec -it rabbitmq-0 -n rabbitmq -- rabbitmqctl list_connections
```

## Maintenance

### Backup

RabbitMQ definitions can be exported via the Management UI or CLI:

```bash
# Export all definitions
kubectl exec -it rabbitmq-0 -n rabbitmq -- rabbitmqctl export_definitions /tmp/definitions.json

# Copy to local machine
kubectl cp rabbitmq/rabbitmq-0:/tmp/definitions.json ./rabbitmq-definitions.json
```

### Restore

```bash
# Copy definitions to pod
kubectl cp ./rabbitmq-definitions.json rabbitmq/rabbitmq-0:/tmp/definitions.json

# Import definitions
kubectl exec -it rabbitmq-0 -n rabbitmq -- rabbitmqctl import_definitions /tmp/definitions.json
```

### Logs

**View pod logs**:
```bash
kubectl logs -n rabbitmq rabbitmq-0 -f
```

**Check for errors**:
```bash
kubectl logs -n rabbitmq rabbitmq-0 | grep -i error
```

## Troubleshooting

### Connection Issues

1. **Verify pod is running**:
   ```bash
   kubectl get pods -n rabbitmq
   ```

2. **Check service endpoints**:
   ```bash
   kubectl get endpoints -n rabbitmq
   ```

3. **Test connection from within cluster**:
   ```bash
   kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
     sh -c "telnet rabbitmq.rabbitmq.svc.cluster.local 5672"
   ```

### Certificate Issues

1. **Check certificate status**:
   ```bash
   kubectl get certificate -n rabbitmq
   kubectl describe certificate -n rabbitmq rabbitmq-dev-tls
   ```

2. **Check Ingress**:
   ```bash
   kubectl get ingress -n rabbitmq
   kubectl describe ingress -n rabbitmq rabbitmq-management
   ```

### Performance Issues

1. **Check resource usage**:
   ```bash
   kubectl top pod -n rabbitmq
   ```

2. **Review queue statistics**:
   ```bash
   kubectl exec -it rabbitmq-0 -n rabbitmq -- rabbitmq-diagnostics status
   ```

### Authentication Errors

If you see `PLAIN login refused: user 'username' - invalid credentials`:

1. **Verify user exists**:
   ```bash
   kubectl exec -it rabbitmq-0 -n rabbitmq -- rabbitmqctl list_users
   ```

2. **Check user permissions on vhost**:
   ```bash
   kubectl exec -it rabbitmq-0 -n rabbitmq -- rabbitmqctl list_permissions -p <vhost>
   ```

3. **Create missing user** (if needed):
   ```bash
   kubectl exec -it rabbitmq-0 -n rabbitmq -- rabbitmqctl add_user <username> <password>
   kubectl exec -it rabbitmq-0 -n rabbitmq -- rabbitmqctl set_permissions -p <vhost> <username> ".*" ".*" ".*"
   ```

### Connection URL Issues After Node Changes

If RabbitMQ connection fails after cluster node changes (e.g., vps7 removal):

1. **Use internal DNS instead of IP/NodePort**:
   - ❌ Bad: `amqp://user:pass@154.26.131.23:30000/vhost`
   - ✅ Good: `amqp://user:pass@rabbitmq.rabbitmq.svc.cluster.local:5672/vhost`

2. **Update secrets with new connection URL**:
   ```bash
   NEW_URL="amqp://user:pass@rabbitmq.rabbitmq.svc.cluster.local:5672/vhost"
   kubectl patch secret <secret-name> -n <namespace> --type='json' \
     -p="[{\"op\": \"replace\", \"path\": \"/data/RABBITMQ_URL\", \"value\": \"$(echo -n "$NEW_URL" | base64)\"}]"
   ```

3. **Restart pods to pick up new connection URL**:
   ```bash
   kubectl rollout restart deployment <deployment-name> -n <namespace>
   ```

## Important Notes

1. **Single Instance**: Current deployment is a single instance without clustering. Not suitable for high-availability production workloads.

2. **Local Storage**: Uses `local-path` storage class, meaning data is tied to the specific node (`vps12-h2cloud-vn`). If the node fails, data may be lost.

3. **Development Environment**: This is a development cluster. For production, consider:
   - Multi-node RabbitMQ cluster
   - Replicated storage (e.g., Longhorn)
   - Resource limits and requests
   - Monitoring and alerting
   - Regular backups

4. **Security**:
   - Management UI is protected by HTTPS
   - Basic authentication with username/password
   - Consider implementing IP whitelisting or VPN access for production

## References

- RabbitMQ Official Documentation: https://www.rabbitmq.com/documentation.html
- RabbitMQ Management Plugin: https://www.rabbitmq.com/management.html
- Kubernetes RabbitMQ Operator: https://www.rabbitmq.com/kubernetes/operator/operator-overview.html

## Related Documentation

- [Dev Cluster Overview](./README.md)
- [PostgreSQL on Dev Cluster](./POSTGRESQL.md)
- [Infrastructure Guide](../../INFRASTRUCTURE.md)

---

Last Updated: 2025-11-04

## Change Log

**2025-11-04**:
- Added `murror-preview` user with credentials for `murror-preview` virtual host
- Updated connection URL in `murror-api-secret` (namespace: `mu-81`) from old vps7 NodePort to internal DNS name
- Fixed RabbitMQ authentication issues after vps7 (154.26.131.23) removal from cluster
- All applications now use internal DNS: `rabbitmq.rabbitmq.svc.cluster.local:5672`

**2025-11-03**:
- Added `murror-dev` user with credentials for `murror_dev` virtual host
- Updated connection examples to include both admin and murror-dev user configurations
- Documented all available users and virtual hosts
