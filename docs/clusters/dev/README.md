# Development Cluster (dev)

*Last Updated: 2025-11-24 (VPS provider changed IPs for 4 nodes)*

## Overview

The development cluster serves as the primary environment for development, testing, and experimentation with new services and configurations.

## Cluster Information

- **Context Name**: `dev`
- **API Endpoint**: <https://180.93.96.54:6443>
- **Environment**: Development
- **Security Level**: Relaxed (see [Security Guidelines](../../SECURITY_GUIDELINES.md#-development-environment))
- **Primary Region**: Vietnam

## Node Configuration

| Node | Role | IP Address | OS Version | Resources |
|------|------|------------|------------|-----------|
| vps5-h2cloud-vn | control-plane, master | 180.93.96.54 | Ubuntu 22.04.2 LTS | 4 CPU, 8GB RAM |
| vps12-h2cloud-vn | worker | 180.93.96.10 | Ubuntu 22.04.2 LTS | 4 CPU, 8GB RAM |
| vps13-h2cloud-vn | worker | 160.191.245.244 | Ubuntu 24.04 LTS | 4 CPU, 8GB RAM |
| vps16-h2cloud-vn | worker | 160.191.245.234 | Ubuntu 24.04 LTS | 4 CPU, 8GB RAM |
| vps17-h2cloud-vn | worker | 180.93.96.15 | Ubuntu 22.04.2 LTS | 4 CPU, 8GB RAM |
| vps18-h2cloud-vn | worker | 180.93.96.101 | Ubuntu 22.04.2 LTS | 4 CPU, 8GB RAM |

## Recent Changes

### 2025-11-24: VPS Provider IP Changes
- **IP Changes**: VPS provider changed IPs for 4 nodes (vps5, vps12, vps17, vps18)
  - vps5-h2cloud-vn: 163.61.110.117 → **180.93.96.54** (Master)
  - vps12-h2cloud-vn: 103.157.204.15 → **180.93.96.10**
  - vps17-h2cloud-vn: 163.61.110.120 → **180.93.96.15**
  - vps18-h2cloud-vn: 160.250.136.247 → **180.93.96.101**
- **API endpoint** changed from `163.61.110.117:6443` to `180.93.96.54:6443`
- **LoadBalancer IPs** updated for all affected services
- **Status**: Configuration updated, pending cluster redeployment when new IPs are accessible

### 2025-11-02: Master Node Migration & Cluster Optimization
- **Master node** transferred from `vps7` (154.26.131.23) to `vps5-h2cloud-vn` (163.61.110.117)
- **vps7 removed** from cluster (old Ubuntu 20.04.5 node retired)
- Cluster completely rebuilt with clean K3s installation
- API endpoint changed from `154.26.131.23:6443` to `163.61.110.117:6443`
- **vps16 and vps13** automatically rejoined after network issue resolved
- All core services restored: PostgreSQL, InfluxDB, Redis (standalone), RabbitMQ, Prometheus, Grafana, Rancher
- **Data loss**: All previous data in local-path volumes was lost during rebuild
- **Final cluster**: 6 nodes (1 master + 5 workers) - all Ubuntu 22.04 or 24.04

## Storage Configuration

### Available Storage Classes

- **local-path** (default): Local storage on nodes
- **longhorn**: Distributed storage (if configured)
- **longhorn-vn**: Region-specific Longhorn storage

### Current Storage Usage

- PostgreSQL HA: Using local-path (10Gi)
- Redis clusters: Using local storage
- Application data: Mixed storage classes

## Network Configuration

### LoadBalancer IPs

The cluster has multiple external IPs available for LoadBalancer services:

- 180.93.96.54 (Primary - control plane node)
- 180.93.96.10 (Worker - vps12)
- 160.191.245.234 (Worker - vps16)
- 160.191.245.244 (Worker - vps13)
- 180.93.96.15 (Worker - vps17)
- 180.93.96.101 (Worker - vps18)

### Ingress Domains

Common development domains:

- `dev.k3s.canhnv.com` - General development services
- `*.ai.api.ambercare.app` - AI service endpoints
- `*.murror.api.ambercare.app` - Murror API endpoints
- `redis.dev.canhnv.com` - Redis management
- `signoz.dev.canhnv.com` - Monitoring
- `influxdb.dev.k3s.canhnv.com` - InfluxDB time-series database
- `grafana.dev.k3s.canhnv.com` - Grafana dashboards
- `prometheus.dev.k3s.canhnv.com` - Prometheus metrics
- `dev.rabbitmq.ambercare.app` - RabbitMQ Management UI

## Key Services

### Databases

#### PostgreSQL HA (postgres-db namespace)

- **Type**: CloudNative PG with pgvector extension
- **Version**: PostgreSQL 17 with pgvector 0.8.0
- **Databases**:
  - `default` - General purpose (owner: dev)
  - `murror-ai` - AI workloads (owner: ai)
  - `murror-be` - Backend services (owner: be)
- **Users**: postgres (superuser), dev, ai, be
- **Access**: Currently ClusterIP only

#### Redis (redis namespace)

- Multiple Redis instances for caching
- RedisInsight UI available at `redis.dev.canhnv.com`

#### RabbitMQ (rabbitmq namespace)

- Message broker for async communication
- **Version**: RabbitMQ 3.13 with Management plugin
- **Management UI**: `https://dev.rabbitmq.ambercare.app` (HTTPS enabled)
- **Internal AMQP**: `amqp://admin:<PASSWORD>@rabbitmq.rabbitmq.svc.cluster.local:5672/`
- **Storage**: 2Gi local-path
- **Documentation**: [RabbitMQ Details](./RABBITMQ.md)

#### InfluxDB (influxdb namespace)

- Time-series database for metrics and analytics
- **Version**: InfluxDB 2.7
- **Organization**: k3s-dev
- **Default Bucket**: dev (7-day retention)
- **Access**: Web UI at `influxdb.dev.k3s.canhnv.com`
- **API**: http://influxdb.influxdb.svc.cluster.local:8086 (internal)

### Development Tools

#### Rancher (cattle-system namespace)

- Cluster management UI
- **UI**: `https://dev.k3s.canhnv.com/dashboard/`
- **API**: `https://dev.k3s.canhnv.com`
- Multi-cluster management capabilities
- **Configuration**: Running with 1 replica (scaled down from 3 due to pod instability on some nodes)
- **Version**: v2.11.2
- **Helm Values**: [apps/rancher/clusters/dev/values.yaml](../../../apps/rancher/clusters/dev/values.yaml)
- **Documentation**: [apps/rancher/README.md](../../../apps/rancher/README.md)

#### SigNoz (signoz namespace)

- Full-stack observability platform
- Available at `signoz.dev.canhnv.com`
- Traces, metrics, and logs

#### Prometheus & Grafana (monitoring namespace)

- Metrics collection and visualization
- Grafana available at `grafana.dev.k3s.canhnv.com`
- 30-day metrics retention
- Pre-configured dashboards for K3s monitoring

### Application Namespaces

Multiple application instances for testing:

- `nsp-alpha-murror-ai` - Alpha AI services
- `ma-26`, `mur-*` - Various test deployments
- `vm-6` - VPS management application

## Common Operations

### Accessing the Cluster

```bash
# Switch to dev context
kubectl config use-context dev

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### Deploying to Dev

```bash
# Using Ansible
ansible-playbook playbooks/site.yml -i inventory.dev.local.yml

# Direct kubectl deployment
kubectl apply -f myapp.yaml -n my-namespace
```

### Port Forwarding (Development Only)

```bash
# PostgreSQL access
kubectl port-forward -n postgres-db svc/postgresql-ha-rw 5432:5432

# Redis access
kubectl port-forward -n redis svc/redis-master 6379:6379

# Application debugging
kubectl port-forward -n my-namespace pod/my-pod 8080:8080
```

### Creating LoadBalancer Services

```yaml
# Example: Expose PostgreSQL for development
apiVersion: v1
kind: Service
metadata:
  name: postgres-dev-external
  namespace: postgres-db
  annotations:
    dev-only: "true"
spec:
  type: LoadBalancer
  selector:
    cnpg.io/cluster: postgresql-ha
    cnpg.io/instanceRole: primary
  ports:
  - port: 5432
    targetPort: 5432
  # Restrict to office/home IPs
  loadBalancerSourceRanges:
  - "YOUR.IP.HERE/32"
```

## Monitoring and Debugging

### Logs

```bash
# Pod logs
kubectl logs -n namespace pod-name -f

# Previous container logs
kubectl logs -n namespace pod-name -p

# All containers in pod
kubectl logs -n namespace pod-name --all-containers
```

### Resource Usage

```bash
# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods -n namespace

# Detailed pod info
kubectl describe pod -n namespace pod-name
```

### Monitoring Integration

#### SigNoz
Access comprehensive monitoring at `signoz.dev.canhnv.com`:
- Application traces
- Infrastructure metrics
- Log aggregation
- Custom dashboards

#### Grafana
Access metrics visualization at `grafana.dev.k3s.canhnv.com`:
- Kubernetes resource metrics
- Node and pod statistics
- Custom application metrics
- Pre-built K3s dashboards

## Development Workflows

### Feature Branch Deployments

1. Create namespace for feature

   ```bash
   kubectl create namespace feature-xyz
   ```

2. Deploy application

   ```bash
   kubectl apply -f app.yaml -n feature-xyz
   ```

3. Create ingress for testing

   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: feature-xyz
     namespace: feature-xyz
   spec:
     ingressClassName: traefik
     rules:
     - host: feature-xyz.dev.domain.com
       http:
         paths:
         - path: /
           pathType: Prefix
           backend:
             service:
               name: app
               port:
                 number: 80
   ```

### Database Access for Development

See [PostgreSQL Documentation](./POSTGRESQL.md) for detailed database access instructions.

## Troubleshooting

### Common Issues

1. **Pod not starting**

   ```bash
   kubectl describe pod -n namespace pod-name
   kubectl logs -n namespace pod-name
   ```

2. **Service not accessible**

   ```bash
   kubectl get endpoints -n namespace
   kubectl get svc -n namespace
   ```

3. **Storage issues**

   ```bash
   kubectl get pv
   kubectl get pvc -n namespace
   kubectl describe pvc -n namespace pvc-name
   ```

4. **Metrics API not available** (error: Metrics API not available)

   **Symptom**: `kubectl top node` or `kubectl top pod` returns "error: Metrics API not available"

   **Cause**: Metrics Server pod failing to reach kubelet due to TLS certificate verification issues

   **Solution**: Add `--kubelet-insecure-tls` flag to metrics-server deployment

   ```bash
   # Patch the metrics-server deployment
   kubectl patch deployment metrics-server -n kube-system --type='json' \
     -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

   # Force delete any stuck pods
   kubectl delete pod -n kube-system -l k8s-app=metrics-server --force --grace-period=0

   # Verify the fix
   kubectl get pods -n kube-system -l k8s-app=metrics-server
   kubectl top node
   ```

   **Verification**:
   - Metrics Server pod should be Running and Ready (1/1)
   - APIService should show as Available: `kubectl get apiservice v1beta1.metrics.k8s.io`
   - `kubectl top node` and `kubectl top pod` commands should work

   *Note: This is safe in development environments where kubelet uses self-signed certificates*

### Useful Commands

```bash
# Get all resources in namespace
kubectl get all -n namespace

# Check events
kubectl get events -n namespace --sort-by='.lastTimestamp'

# Shell into pod
kubectl exec -it -n namespace pod-name -- /bin/bash

# Copy files from pod
kubectl cp namespace/pod-name:/path/to/file ./local-file
```

## Best Practices

1. **Namespace Isolation**: Use separate namespaces for different features/teams
2. **Resource Limits**: Set appropriate requests/limits even in dev
3. **Clean Up**: Regularly clean up unused resources
4. **Documentation**: Document any permanent changes
5. **Testing**: Test configurations here before promoting to staging/prod

## Related Documentation

- [PostgreSQL Setup](./POSTGRESQL.md)
- [RabbitMQ Setup](./RABBITMQ.md)
- [Service Configurations](./SERVICES.md)
- [Security Guidelines for Dev](../../SECURITY_GUIDELINES.md#-development-environment)
- [Infrastructure Overview](../../INFRASTRUCTURE.md)
