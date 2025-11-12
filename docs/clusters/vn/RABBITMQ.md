# RabbitMQ on VN Cluster

## Overview

RabbitMQ is deployed on the VN cluster to provide message broker capabilities for applications requiring asynchronous messaging, task queues, and pub/sub patterns.

## Deployment Information

- **Namespace**: `rabbitmq`
- **Deployment Method**: Helm Chart (Bitnami RabbitMQ)
- **Chart Version**: 16.0.11
- **App Version**: 4.1.2
- **Helm Revision**: 3 (rolled back from 2)
- **Replicas**: 1 (single instance)
- **Storage**: 2Gi persistent volume using `longhorn-vn` storage class
- **Node Assignment**: Storage nodes (with role=storage label)

## Access Information

### Internal Access (Within Cluster)

**AMQP Connection** (for applications):
```
amqp://rabbitmq:__REDACTED__@rabbitmq.rabbitmq.svc.cluster.local:5672/
```

**Connection Details**:
- Host: `rabbitmq.rabbitmq.svc.cluster.local`
- AMQP Port: `5672`
- Management Port: `15672`
- Username: `rabbitmq`
- Password: `__REDACTED__`

### External Access

**LoadBalancer Service**:
- AMQP: `14.225.210.108:30000` (NodePort)
- External IPs: `14.225.210.108`, `14.225.210.165`, `14.225.210.170`

**Management Dashboard**:
- URL: `https://rabbitmq.ambercare.app`
- Username: `rabbitmq`
- Password: `__REDACTED__`
- TLS: Enabled via cert-manager with Let's Encrypt (Production)

## Configuration

### Credentials

Credentials are stored in Kubernetes secret:
```bash
kubectl get secret -n rabbitmq rabbitmq -o jsonpath='{.data.rabbitmq-password}' | base64 -d
kubectl get secret -n rabbitmq rabbitmq -o jsonpath='{.data.rabbitmq-erlang-cookie}' | base64 -d
```

### Services

| Service Name | Type | Ports | Purpose |
|--------------|------|-------|---------|
| `rabbitmq` | LoadBalancer | 5672, 4369, 25672, 15672 | Main service endpoint |
| `rabbitmq-headless` | ClusterIP | 4369, 5672, 25672, 15672 | Headless service for StatefulSet |

### Ingress

The RabbitMQ Management UI is exposed via Traefik Ingress:
- Host: `rabbitmq.ambercare.app`
- TLS: Managed by cert-manager using `ambercare-app` ClusterIssuer (Production)
- Certificate Secret: `rabbitmq.ambercare.app-tls`
- Certificate Issuer: Let's Encrypt Production (R12)
- Certificate Valid: Nov 12 2025 - Feb 10 2026

### Storage

- **Storage Class**: `longhorn-vn`
- **Size**: 2Gi
- **Access Mode**: ReadWriteOnce
- **Reclaim Policy**: Retain

### Node Placement

The RabbitMQ pod is scheduled on storage nodes with:
- **Node Selector**: `role=storage`
- **Tolerations**:
  - `dedicated=storage:NoSchedule`

## Helm Configuration

The deployment uses cluster-specific values located at:
```
rabbitmq/clusters/vn/values.yaml
```

Key configurations:
- Storage class: `longhorn-vn`
- Ingress hostname: `rabbitmq.ambercare.app`
- ClusterIssuer: `ambercare-app` (Production)
- Plugins: `rabbitmq_management`, `rabbitmq_prometheus`, `rabbitmq_shovel`, `rabbitmq_shovel_management`

## Usage Examples

### Application Connection

**Node.js** (using amqplib):
```javascript
const amqp = require('amqplib');

const connection = await amqp.connect(
  'amqp://rabbitmq:__REDACTED__@rabbitmq.rabbitmq.svc.cluster.local:5672/'
);
const channel = await connection.createChannel();
```

**Python** (using pika):
```python
import pika

credentials = pika.PlainCredentials('rabbitmq', '__REDACTED__')
parameters = pika.ConnectionParameters(
    'rabbitmq.rabbitmq.svc.cluster.local',
    5672,
    '/',
    credentials
)
connection = pika.BlockingConnection(parameters)
channel = connection.channel()
```

**Environment Variables**:
```bash
export RABBITMQ_URL="amqp://rabbitmq:__REDACTED__@rabbitmq.rabbitmq.svc.cluster.local:5672/"
export RABBITMQ_HOST=rabbitmq.rabbitmq.svc.cluster.local
export RABBITMQ_PORT=5672
export RABBITMQ_USERNAME=rabbitmq
export RABBITMQ_PASSWORD=__REDACTED__
export RABBITMQ_VHOST=/
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

Access the management dashboard at `https://rabbitmq.ambercare.app` to view:
- Queue statistics
- Connection details
- Message rates
- Memory and disk usage
- Cluster overview

### Prometheus Metrics

RabbitMQ exposes Prometheus metrics on port 15692:
```bash
kubectl port-forward -n rabbitmq rabbitmq-0 15692:15692
curl http://localhost:15692/metrics
```

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

### Upgrade

To upgrade RabbitMQ to a new version:
```bash
helm upgrade rabbitmq oci://registry-1.docker.io/bitnamicharts/rabbitmq \
  --namespace rabbitmq \
  --values /path/to/k3s-ansible/rabbitmq/clusters/vn/values.yaml
```

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

The VN cluster was previously using Let's Encrypt **staging** certificates which caused SSL errors (Cloudflare Error 526) because staging certificates are not trusted by browsers or Cloudflare.

**Resolution (2025-11-12)**:
- Switched from `ambercare-app-staging` to `ambercare-app` (production) ClusterIssuer
- Deleted old staging certificate and secret
- New production certificate issued successfully by Let's Encrypt

**Check certificate status**:
```bash
kubectl get certificate -n rabbitmq
kubectl describe certificate -n rabbitmq rabbitmq.ambercare.app-tls
```

**Verify production issuer**:
```bash
kubectl get certificate rabbitmq.ambercare.app-tls -n rabbitmq -o jsonpath='{.spec.issuerRef.name}'
# Should output: ambercare-app
```

**Check certificate details**:
```bash
kubectl get secret rabbitmq.ambercare.app-tls -n rabbitmq -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -issuer -subject -dates
# Issuer should be: Let's Encrypt R12 or R13 (production, not Fake LE)
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

2. **Check user permissions**:
   ```bash
   kubectl exec -it rabbitmq-0 -n rabbitmq -- rabbitmqctl list_permissions -p /
   ```

## Important Notes

1. **Single Instance**: Current deployment is a single instance without clustering. For high-availability production workloads, consider multi-node clustering.

2. **Longhorn Storage**: Uses `longhorn-vn` storage class with replication for data persistence and availability.

3. **Production TLS Certificate**: Uses Let's Encrypt production certificates (not staging) to ensure browser and Cloudflare trust.

4. **Node Placement**: Scheduled on storage nodes to ensure data locality and persistence.

5. **Security**:
   - Management UI is protected by HTTPS with valid production certificate
   - Basic authentication with username/password
   - Consider implementing IP whitelisting or VPN access for enhanced security

## References

- RabbitMQ Official Documentation: https://www.rabbitmq.com/documentation.html
- RabbitMQ Management Plugin: https://www.rabbitmq.com/management.html
- Bitnami RabbitMQ Helm Chart: https://github.com/bitnami/charts/tree/main/bitnami/rabbitmq

## Related Documentation

- [VN Cluster Overview](./README.md)
- [Infrastructure Guide](../../INFRASTRUCTURE.md)
- [Security Guidelines](../../SECURITY_GUIDELINES.md)

---

Last Updated: 2025-11-12

## Change Log

**2025-11-12**:
- Fixed SSL certificate error (Cloudflare Error 526) by switching from staging to production ClusterIssuer
- **Issue 1**: Initial Helm upgrade to chart 16.0.14 caused ImagePullBackOff (image 4.1.3-debian-12-r1 not available)
- **Solution**: Rolled back to revision 1 (chart 16.0.11, app 4.1.2) which uses available image
- Updated ingress annotation from `ambercare-app-staging` to `ambercare-app` (production)
- Deleted old staging certificate and regenerated with production issuer
- New certificate issued by Let's Encrypt R12 (production), valid Nov 12 2025 - Feb 10 2026
- Current deployment: Chart 16.0.11, App Version 4.1.2, Revision 3 (rolled back from 2)
- Initial documentation created for VN cluster RabbitMQ deployment
- Created VN-specific configuration directory structure at `rabbitmq/clusters/vn/`
