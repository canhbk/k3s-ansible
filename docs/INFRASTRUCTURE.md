# K3s Infrastructure Overview

This document describes the common infrastructure patterns and components used across all K3s clusters.

## Architecture Overview

### K3s Distribution

All clusters run K3s - a lightweight Kubernetes distribution optimized for:

- Edge computing
- IoT devices
- Development environments
- Resource-constrained servers

**Current Version**: v1.30.2+k3s1 (as deployed on dev cluster)

### Node Architecture

#### Control Plane Nodes

- Run K3s server components
- Embedded etcd for HA configurations
- API server, scheduler, controller-manager
- Can also run workloads (unlike traditional K8s)

#### Worker Nodes

- Run K3s agent components
- Execute container workloads
- Connect to control plane via token authentication

### High Availability Patterns

1. **Single Server** (Development)
   - One control plane node
   - Multiple worker nodes
   - Suitable for dev/test environments

2. **HA with Embedded etcd** (Production)
   - 3, 5, or 7 control plane nodes
   - Automatic etcd cluster formation
   - No external database required

3. **HA with External Database**
   - PostgreSQL or MySQL as datastore
   - Unlimited control plane nodes
   - Better for very large clusters

## Storage Architecture

### Storage Classes

#### Longhorn (Distributed Storage)

- **Storage Class**: `longhorn`, `longhorn-vn`
- **Use Cases**: Stateful applications requiring replication
- **Features**:
  - Multi-replica volumes
  - Snapshots and backups
  - Cross-node replication
  - Storage node affinity (nodes labeled with `longhorn=true`)

#### Local Path Provisioner

- **Storage Class**: `local-path`
- **Use Cases**: Development, single-node deployments
- **Features**:
  - Simple local directory volumes
  - No replication
  - Fast performance
  - Default K3s storage class

### Persistent Volume Patterns

```yaml
# Example: PostgreSQL with Longhorn storage
storage:
  storageClass: longhorn-vn
  size: 5Gi

# Example: Development with local storage
storage:
  storageClass: local-path
  size: 10Gi
```

## Networking

### Service Types

1. **ClusterIP** (Default)
   - Internal cluster access only
   - Used for inter-service communication

2. **NodePort**
   - Exposes service on all nodes
   - Port range: 30000-32767
   - Example: `postgres` in mur-742 namespace (30451)

3. **LoadBalancer**
   - External access with cloud provider integration
   - Dev cluster has MetalLB or similar configured
   - Assigns external IPs automatically

### Ingress Architecture

**Traefik** - Default K3s ingress controller

- Automatic HTTPS with Let's Encrypt
- Dynamic configuration
- Middleware support (auth, rate limiting)
- WebSocket support

Common ingress pattern:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - app.domain.com
    secretName: app-tls
  rules:
  - host: app.domain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

## Container Runtime

- **containerd**: Default K3s container runtime
- Version: 1.7.17-k3s1 (bundled with K3s)
- Supports standard OCI images
- CRI-compliant

## DNS Architecture

### CoreDNS

- Cluster DNS provider
- Service discovery via `servicename.namespace.svc.cluster.local`
- Configurable upstream DNS servers
- Custom DNS entries support

## Service Mesh Capabilities

While not deployed by default, K3s supports:

- **Linkerd**: Lightweight service mesh
- **Istio**: Full-featured service mesh (resource intensive)
- **Traefik Mesh**: Simple service mesh by Traefik

## Monitoring and Observability

### Available Solutions

1. **SigNoz** (Deployed on dev)
   - Full-stack observability
   - Traces, metrics, logs
   - OpenTelemetry native

2. **Prometheus + Grafana**
   - Metrics collection and visualization
   - K3s metrics available via `/metrics` endpoints

3. **Rancher** (Deployed on dev)
   - Cluster management UI
   - Multi-cluster management
   - Built-in monitoring options

## Security Infrastructure

### RBAC (Role-Based Access Control)

- Enabled by default in K3s
- Service accounts for applications
- Role and ClusterRole definitions
- Namespace isolation

### Network Policies

- Calico or default K3s network policies
- Pod-to-pod communication control
- Ingress/egress rules

### Secrets Management

- Kubernetes secrets (base64 encoded)
- Integration with external secret managers possible
- Encryption at rest (when configured)

## Backup and Disaster Recovery

### etcd Snapshots

- Automatic snapshots (configurable)
- Manual snapshot commands
- Stored locally or S3-compatible storage

### Application Backup Strategies

1. **Database-specific**:
   - CloudNative PG built-in backup
   - Volume snapshots with Longhorn

2. **Velero** (Optional):
   - Cluster-wide backup solution
   - Scheduled backups
   - Cross-cluster migration

## Resource Management

### Namespace Organization

Common namespace patterns:

- `default` - Avoid using in production
- `kube-system` - K3s system components
- `{app}-{env}` - Environment-specific apps
- `{team}-{project}` - Team-based isolation

### Resource Quotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
spec:
  hard:
    requests.cpu: "100"
    requests.memory: 200Gi
    limits.cpu: "200"
    limits.memory: 400Gi
```

### Pod Resource Limits

Best practices:

- Always set resource requests
- Set limits for memory
- CPU limits optional (can cause throttling)

## Common Deployment Patterns

### GitOps

- ArgoCD or Flux for declarative deployments
- Git as source of truth
- Automatic synchronization

### Helm Charts

- Package management for Kubernetes
- Templating and versioning
- Used for complex applications (PostgreSQL, Redis, etc.)

### Kustomize

- Built into kubectl
- Overlay configurations
- Environment-specific customizations

## Performance Optimization

### Node Affinity

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: node-type
          operator: In
          values:
          - high-memory
```

### Pod Disruption Budgets

Ensure availability during updates:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: myapp
```

## Related Documentation

- [Clusters Overview](./CLUSTERS_OVERVIEW.md)
- [Security Guidelines](./SECURITY_GUIDELINES.md)
- [PostgreSQL Setup](./services/postgresql/SETUP.md)
- [Longhorn Configuration](../longhorn/README.md)
