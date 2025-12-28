# SG3 Cluster - Deployed Services

## Overview

This document provides a quick reference for all services deployed on the SG3 cluster, including access URLs, namespaces, and authentication information.

**Last Updated**: 2025-12-11

## Service Directory

### Infrastructure & Management

| Service | URL | Namespace | Purpose | Authentication |
|---------|-----|-----------|---------|----------------|
| **Rancher** | https://rancher.sg3.canhnv.com | cattle-system | Kubernetes cluster management UI | admin / (bootstrap password) |
| **Longhorn** | https://sg3.longhorn.canhnv.com | longhorn-system | Distributed storage management UI | Basic Auth (see ingress.yaml) |

### Monitoring & Observability

| Service | URL | Namespace | Purpose | Authentication |
|---------|-----|-----------|---------|----------------|
| **Grafana** | https://grafana.sg3.k3s.canhnv.com | monitoring | Metrics visualization and dashboards | admin / (get from secret) |
| **Prometheus** | https://prometheus.sg3.k3s.canhnv.com | monitoring | Metrics collection and time-series DB | N/A |
| **Loki** | https://loki.sg3.k3s.canhnv.com | monitoring | Log aggregation and querying | N/A (accessed via Grafana) |

### Databases

| Service | URL | Namespace | Purpose | Authentication |
|---------|-----|-----------|---------|----------------|
| **pgAdmin** | https://pgadmin.sg3.k3s.canhnv.com | postgres-db | PostgreSQL database administration | admin@canhnv.com / (from secret) |
| **PostgreSQL (Internal)** | postgresql-sg3-pgvector-rw.postgres-db.svc.cluster.local:5432 | postgres-db | PostgreSQL 17.2 HA cluster with pgvector | postgres / app / murror / murror-ai |
| **PostgreSQL (External - NodePort)** | <any-node-ip>:31432 | postgres-db | Direct IP access for development/debugging | postgres / app / murror / murror-ai |
| **InfluxDB** | https://influxdb.sg3.k3s.canhnv.com | influxdb | Time-series database for metrics | admin / (from secret) |

### Message Queues

| Service | URL | Namespace | Purpose | Authentication |
|---------|-----|-----------|---------|----------------|
| **RabbitMQ** | https://rabbitmq.sg3.canhnv.com | rabbitmq | Message broker HA cluster (3 replicas) | (from secret rabbitmq-default-user) |

## Accessing Services

### External Access (via Browser)

All external services use HTTPS with automatic TLS certificates from Let's Encrypt via cert-manager:

```bash
# Simply navigate to the service URL in your browser
open https://grafana.sg3.k3s.canhnv.com
open https://pgadmin.sg3.k3s.canhnv.com
open https://rancher.sg3.canhnv.com
```

### Internal Access (within cluster)

Services can be accessed internally using Kubernetes DNS:

```bash
# PostgreSQL read-write endpoint
postgresql-sg3-pgvector-rw.postgres-db.svc.cluster.local:5432

# PostgreSQL read-only endpoint
postgresql-sg3-pgvector-ro.postgres-db.svc.cluster.local:5432

# RabbitMQ AMQP endpoint
rabbitmq.rabbitmq.svc.cluster.local:5672

# Loki gateway
loki-gateway.monitoring.svc.cluster.local

# InfluxDB endpoint
influxdb-influxdb2.influxdb.svc.cluster.local:8086
```

### External Database Access (NodePort)

For development and debugging purposes, the PostgreSQL cluster can be accessed directly via any node IP:

```bash
# Connect using node IP + NodePort 31432
psql "postgresql://app@10.10.0.51:31432/app"
psql "postgresql://murror@10.10.0.52:31432/app"

# With external IPs (if accessible)
psql "postgresql://app@15.235.211.39:31432/app"
```

**Available Node IPs**:
- Internal: 10.10.0.50-57 (any node)
- External: 15.235.197.155, 15.235.211.39, etc. (check firewall rules)

**Note**: The NodePort service targets the primary instance only for read-write operations. For read-only access, use the internal cluster services.

**See**: [database/postgresql/clusters/sg3/EXTERNAL_ACCESS.md](../../../database/postgresql/clusters/sg3/EXTERNAL_ACCESS.md) for comprehensive connection examples.

### Port Forwarding (for non-ingress services)

```bash
# Alertmanager
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093

# Prometheus (if ingress not used)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

## Retrieving Credentials

### Grafana Admin Password

```bash
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d && echo
```

### Rancher Bootstrap Password

```bash
kubectl get secret --namespace cattle-system bootstrap-secret \
  -o go-template='{{.data.bootstrapPassword|base64decode}}{{"\n"}}'
```

### pgAdmin Admin Password

```bash
kubectl get secret pgadmin-admin -n postgres-db \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

### PostgreSQL Passwords

```bash
# Superuser (postgres)
kubectl get secret superuser-sg3-secret -n postgres-db \
  -o jsonpath='{.data.password}' | base64 -d && echo

# App user
kubectl get secret app-sg3-secret -n postgres-db \
  -o jsonpath='{.data.password}' | base64 -d && echo

# Murror user
kubectl get secret murror-sg3-secret -n postgres-db \
  -o jsonpath='{.data.password}' | base64 -d && echo

# Murror-AI user
kubectl get secret murror-ai-sg3-secret -n postgres-db \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

### InfluxDB Admin Password

```bash
kubectl get secret influxdb-auth -n influxdb \
  -o jsonpath='{.data.admin-password}' | base64 -d && echo
```

### RabbitMQ Credentials

```bash
# Get username
kubectl get secret rabbitmq-default-user -n rabbitmq \
  -o jsonpath='{.data.username}' | base64 -d && echo

# Get password
kubectl get secret rabbitmq-default-user -n rabbitmq \
  -o jsonpath='{.data.password}' | base64 -d && echo

# Get full connection URL
kubectl get secret rabbitmq-default-user -n rabbitmq \
  -o jsonpath='{.data.connection_string}' | base64 -d && echo
```

**Note**: For detailed connection information and examples, see [rabbitmq/clusters/sg3/CONNECTION_INFO.md](../../../rabbitmq/clusters/sg3/CONNECTION_INFO.md)

## Service Health Checks

### Check All Services Status

```bash
# Check pods in all namespaces
kubectl get pods -A

# Check specific namespaces
kubectl get pods -n monitoring
kubectl get pods -n postgres-db
kubectl get pods -n rabbitmq
kubectl get pods -n longhorn-system
kubectl get pods -n cattle-system
```

### Check Ingress Status

```bash
# List all ingresses
kubectl get ingress -A

# Check specific ingress
kubectl describe ingress pgadmin -n postgres-db
kubectl describe ingress grafana -n monitoring
```

### Check TLS Certificates

```bash
# List all certificates
kubectl get certificate -A

# Check specific certificate
kubectl describe certificate pgadmin-sg3-tls -n postgres-db
kubectl describe certificate grafana-sg3-tls -n monitoring
```

## Service Documentation

Detailed documentation for each service:

- **pgAdmin**: [pgadmin/clusters/sg3/README.md](../../../pgadmin/clusters/sg3/README.md)
- **PostgreSQL**: [database/postgresql/clusters/sg3/README.md](../../../database/postgresql/clusters/sg3/README.md)
- **Longhorn**: [longhorn/clusters/sg3/README.md](../../../longhorn/clusters/sg3/README.md)
- **Rancher**: [apps/rancher/clusters/sg3/README.md](../../../apps/rancher/clusters/sg3/README.md)
- **Monitoring**: [monitoring/clusters/sg3/README.md](../../../monitoring/clusters/sg3/README.md)
- **RabbitMQ**: [rabbitmq/clusters/sg3/README.md](../../../rabbitmq/clusters/sg3/README.md)

## Network Configuration

### DNS Patterns

Services follow consistent DNS patterns:

- **Kubernetes internal**: `<service>.<namespace>.svc.cluster.local`
- **External (k3s subdomain)**: `<service>.sg3.k3s.canhnv.com`
- **External (canhnv.com)**: `<service>.sg3.canhnv.com` or `sg3.<service>.canhnv.com`

### Port Numbers

Standard port conventions:

- **HTTP/HTTPS**: 80/443 (via Ingress)
- **PostgreSQL**: 5432
- **RabbitMQ AMQP**: 5672
- **RabbitMQ Management**: 15672
- **Prometheus**: 9090
- **Alertmanager**: 9093
- **Grafana**: 80 (via Ingress)
- **Loki**: 3100 (internal), 80 (via Ingress)

## Security Notes

1. **All external services** use HTTPS with TLS certificates from Let's Encrypt
2. **Passwords** are stored in Kubernetes secrets (never in Git)
3. **Basic Auth** is used for Longhorn UI access
4. **Built-in authentication** is used for Grafana, pgAdmin, RabbitMQ, Rancher
5. **Network policies** may be applied to restrict pod-to-pod communication

## Troubleshooting

### Service Not Accessible

1. Check pod status: `kubectl get pods -n <namespace>`
2. Check service: `kubectl get svc -n <namespace>`
3. Check ingress: `kubectl get ingress -n <namespace>`
4. Check TLS certificate: `kubectl get certificate -n <namespace>`
5. Check cert-manager logs: `kubectl logs -n cert-manager -l app=cert-manager`

### TLS Certificate Issues

```bash
# Check certificate status
kubectl describe certificate <cert-name> -n <namespace>

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager --tail=100

# Force certificate renewal
kubectl delete certificate <cert-name> -n <namespace>
# Certificate will be automatically recreated by cert-manager
```

### Database Connection Issues

```bash
# Test PostgreSQL connectivity from within cluster
kubectl run psql-test --rm -it --image=postgres:17 -- bash
psql postgresql://postgres@postgresql-sg3-pgvector-rw.postgres-db.svc.cluster.local/postgres

# Check PostgreSQL cluster status
kubectl get cluster -n postgres-db
kubectl describe cluster postgresql-sg3-pgvector -n postgres-db
```

## Change Log

- **2025-12-03**:
  - Upgraded RabbitMQ to version 4.0.9-management-alpine
  - Deployed InfluxDB 2.7 time-series database for Subeo organization (20Gi local-path storage)
- **2025-12-02**: Deployed Loki log aggregation system (Simple Scalable Deployment with 15-day retention)
- **2025-12-01**: Added pgAdmin for PostgreSQL database administration
- **2025-11-26**: Added RabbitMQ HA cluster deployment (RabbitMQ Cluster Operator)
- **2025-11-25**:
  - Deployed Prometheus and Grafana monitoring stack with Longhorn storage
  - Added PostgreSQL 17.2 HA cluster with pgvector extension
  - Deployed Longhorn distributed storage v1.9.1
  - Deployed Rancher v2.11.2 for cluster management
- **2025-11-24**: Initial cluster setup with cert-manager and TLS certificates
