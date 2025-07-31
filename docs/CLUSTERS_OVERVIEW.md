# K3s Clusters Overview

This document provides a comprehensive overview of all K3s clusters managed by this repository.

## Cluster Summary

| Cluster | Environment | Context | API Endpoint | Primary Use | Region |
|---------|-------------|---------|--------------|-------------|--------|
| dev | Development | `dev` | <https://154.26.131.23:6443> | Development & Testing | US |
| eu | Production | `eu` | <https://31.14.17.182:6443> | EU Production Services | Europe |
| jp | Production | `jp` | <https://84.247.152.54:6443> | Japan Production Services | Asia-Pacific |
| sg | Production | `sg` | <https://46.250.232.0:6443> | Singapore Production Services | Asia-Pacific |
| sg2 | Production | `sg2` | <https://46.250.231.255:6443> | Singapore Secondary Services | Asia-Pacific |
| us | Production | `us` | <https://65.49.60.35:6443> | US Production Services | North America |
| vn | Production | `vn` | <https://vps22.canhnv.com:6443> | Vietnam Production Services | Asia-Pacific |
| vn2 | Production | `vn2` | <https://163.61.73.78:6443> | Vietnam Secondary Services | Asia-Pacific |

## Cluster Details

### Development Cluster (dev)

- **Purpose**: Development, testing, and experimentation
- **Security Level**: Relaxed (development environment)
- **Current Context**: Active (as of last check)
- **Default Namespace**: `nsp-alpha-murror-ai`
- **Key Services**:
  - PostgreSQL HA (postgres-db namespace)
  - Redis clusters
  - RabbitMQ
  - Multiple development applications
  - Rancher management UI
  - SigNoz monitoring

### Production Clusters

#### EU Cluster

- **Purpose**: European production services
- **Security Level**: Strict
- **Default Namespace**: `default`
- **Compliance**: GDPR compliant infrastructure

#### JP Cluster

- **Purpose**: Japan region production services
- **Security Level**: Strict
- **Default Namespace**: `default`
- **Key Considerations**: Low latency for Asia-Pacific users

#### SG Cluster (Singapore)

- **Purpose**: Primary Singapore production services
- **Security Level**: Strict
- **Default Namespace**: `cert-manager`
- **Special Features**: Certificate management hub

#### SG2 Cluster (Singapore Secondary)

- **Purpose**: Secondary/backup Singapore services
- **Security Level**: Strict
- **Default Namespace**: `nsp-p-ambercare`
- **Key Services**: Ambercare production workloads

#### US Cluster

- **Purpose**: US production services
- **Security Level**: Strict
- **Default Namespace**: `default`
- **Compliance**: US data residency requirements

#### VN Cluster (Vietnam)

- **Purpose**: Primary Vietnam production services
- **Security Level**: Strict
- **Default Namespace**: `postgres-db`
- **Special Features**: Database-centric workloads

#### VN2 Cluster (Vietnam Secondary)

- **Purpose**: Secondary Vietnam services
- **Security Level**: Strict
- **Default Namespace**: `nsp-prod-murror`
- **Key Services**: Murror production workloads

## Access Management

### Switching Between Clusters

```bash
# List all contexts
kubectl config get-contexts

# Switch to a specific cluster
kubectl config use-context dev
kubectl config use-context eu
kubectl config use-context jp
# ... etc

# Verify current context
kubectl config current-context
```

### Authentication

All clusters use certificate-based authentication with:

- Client certificates stored in kubeconfig
- Certificate authority validation
- No token-based authentication for enhanced security

## Network Architecture

### LoadBalancer Support

Development cluster (dev) has LoadBalancer service support with multiple external IPs:

- 154.26.131.23 (Primary)
- 154.38.172.89
- 209.126.10.183
- 46.250.232.10
- 5.104.86.195

### Ingress Controller

All clusters use Traefik as the default ingress controller, providing:

- Automatic HTTPS with Let's Encrypt
- Load balancing
- Path-based and host-based routing

## Inventory Files

Each cluster has its corresponding inventory file:

- `inventory.dev.yml` - Development cluster
- `inventory.prod.yml` - General production template
- `inventory.us.yml` - US cluster specific
- `inventory.eu.yml` - EU cluster specific (if exists)
- `inventory.vn.yml` - Vietnam primary cluster
- `inventory.vn-2.yml` - Vietnam secondary cluster

## Common Operations

### Deploy to a Specific Cluster

```bash
# Deploy to dev cluster
ansible-playbook playbooks/site.yml -i inventory.dev.yml

# Deploy to production US
ansible-playbook playbooks/site.yml -i inventory.us.yml

# Deploy to Vietnam cluster
ansible-playbook playbooks/site.yml -i inventory.vn.yml
```

### Health Check All Clusters

```bash
# Quick health check script
for context in dev eu jp sg sg2 us vn vn2; do
  echo "Checking cluster: $context"
  kubectl config use-context $context
  kubectl get nodes
  echo "---"
done
```

## Best Practices

1. **Environment Separation**: Never apply production configurations to development
2. **Context Verification**: Always verify current context before applying changes
3. **Backup First**: Take backups before major changes, especially in production
4. **Rolling Updates**: Use staged rollouts across regions
5. **Documentation**: Update cluster-specific docs when making changes

## Related Documentation

- [Infrastructure Overview](./INFRASTRUCTURE.md)
- [Security Guidelines](./SECURITY_GUIDELINES.md)
- [Dev Cluster Details](./clusters/dev/README.md)
- [Production Cluster Guidelines](./clusters/production/README.md)
