# Development Cluster (dev)

*Last Updated: 2025-10-18 (Node vps15 removed from cluster)*

## Overview

The development cluster serves as the primary environment for development, testing, and experimentation with new services and configurations.

## Cluster Information

- **Context Name**: `dev`
- **API Endpoint**: <https://154.26.131.23:6443>
- **Environment**: Development
- **Security Level**: Relaxed (see [Security Guidelines](../../SECURITY_GUIDELINES.md#-development-environment))
- **Primary Region**: US

## Node Configuration

| Node | Role | IP Address | Resources | Special Labels |
|------|------|------------|-----------|----------------|
| vps7 | control-plane, master | 154.26.131.23 | Ubuntu 20.04.5 LTS | - |
| vps16-h2cloud-vn | worker | 160.191.245.234 | Ubuntu 24.04 LTS | - |
| vps17-h2cloud-vn | worker | 163.61.110.120 | Ubuntu 22.04.2 LTS | - |
| vps5-h2cloud-vn | worker | 163.61.110.117 | Ubuntu 22.04.2 LTS | - |
| vps18-h2cloud-vn | worker | 160.250.136.247 | Ubuntu 22.04.2 LTS | - |
| vps12-h2cloud-vn | worker | 103.157.204.15 | Ubuntu 22.04.2 LTS | - |
| vps13-h2cloud-vn | worker | 160.191.245.244 | Ubuntu 24.04 LTS | - |

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

- 154.26.131.23 (Primary - also control plane)
- 160.191.245.234
- 163.61.110.120
- 163.61.110.117
- 160.250.136.247
- 103.157.204.15
- 160.191.245.244

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
- Management UI at `dev.rabbitmq.ambercare.app`

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
- Available at `dev.k3s.canhnv.com`
- Multi-cluster management capabilities

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
- [Service Configurations](./SERVICES.md)
- [Security Guidelines for Dev](../../SECURITY_GUIDELINES.md#-development-environment)
- [Infrastructure Overview](../../INFRASTRUCTURE.md)
