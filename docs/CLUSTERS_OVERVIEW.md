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
| sg3 | Production | `sg3` | <https://15.235.211.39:6443> | Singapore OVH Production Services | Asia-Pacific |
| us | Production | `us` | <https://65.49.60.35:6443> | US Production Services | North America |
| vn | Production | `vn` | <https://vps22.canhnv.com:6443> | Vietnam Production Services | Asia-Pacific |
| vn2 | CI/CD Infrastructure | N/A | N/A (GitHub Runners) | GitHub Actions Self-Hosted Runners | Asia-Pacific |

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

#### SG3 Cluster (Singapore OVH)

- **Purpose**: OVH Singapore production services
- **Security Level**: Strict
- **Provider**: OVH Cloud
- **Cluster Configuration**:
  - 3 Control Plane Nodes: vps51 (10.10.0.51), vps52 (10.10.0.52), vps54 (10.10.0.54)
  - 5 Agent Nodes: vps50 (10.10.0.50), vps53 (10.10.0.53), vps55 (10.10.0.55), vps56 (10.10.0.56), vps57 (10.10.0.57)
- **Network Configuration**:
  - Pod CIDR: 10.54.0.0/16
  - Service CIDR: 10.55.0.0/16
  - Cluster DNS: 10.55.0.10
  - Wireguard mesh network over wg0 interface
  - Wireguard IPs: 10.10.0.50-57
- **K3s Version**: v1.32.5+k3s1
- **OS**: Ubuntu 24.04.3 LTS
- **Setup Method**: k3sup
- **API Endpoint**: <https://15.235.211.39:6443>
- **Region Label**: `region=sg3`
- **Created**: 2025-11-24
- **Key Services**:
  - Auth Service (Alpha) - `auth-alpha.ambercare.app`
  - PostgreSQL HA (postgres-db namespace) with pgvector
  - RabbitMQ HA cluster
  - Prometheus/Grafana monitoring
  - Longhorn distributed storage
  - Rancher management UI
  - InfluxDB time-series database

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

#### VN2 Infrastructure (GitHub Runners)

> **Note**: VN2 has been converted from a K3s cluster to GitHub Actions self-hosted runner infrastructure.

- **Purpose**: CI/CD for murror and canh-nv organizations
- **Infrastructure Type**: Self-Hosted GitHub Actions Runners
- **Total Runners**: 8 runners across 4 nodes
- **Organizations**: murror, canh-nv
- **Runner Nodes**:
  - vps28-bnix (163.61.73.77): vn2-murror-1, vn2-canh-nv-1
  - vps29-bnix (163.61.73.78): vn2-murror-2, vn2-canh-nv-2
  - vps30-bnix (163.61.73.79): vn2-murror-3, vn2-canh-nv-3
  - vps31-bnix (163.61.73.90): vn2-murror-4, vn2-canh-nv-4
- **Capabilities**: Docker, Node.js 22, pnpm, kubectl, Helm
- **Documentation**: [VN2 GitHub Runners Guide](./clusters/vn2/GITHUB_RUNNERS.md)
- **Last Updated**: 2026-01-25

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

## Cluster Management Methods

### Ansible-Managed Clusters
These clusters use Ansible playbooks with inventory files:

- `inventory.dev.local.yml` - Development cluster
- `inventory.vn.yml` - Vietnam primary cluster
- `inventory.vn-2.yml` - Vietnam secondary cluster
- `inventory.prod.yml` - General production template

### Manually-Managed Clusters
These clusters use manual K3s installation (see `k3s-with-k3sup/manual.md`):

- **US Cluster** - Manual setup with k3s install script
- **EU Cluster** - Manual setup with k3s install script
- **JP Cluster** - Manual setup with k3s install script
- **SG Cluster** - Manual setup with k3s install script
- **SG2 Cluster** - Manual setup with k3s install script

## Common Operations

### Deploy to a Specific Cluster

```bash
# Deploy to dev cluster
ansible-playbook playbooks/site.yml -i inventory.dev.local.yml

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
