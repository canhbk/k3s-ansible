# EU Cluster Overview

## Cluster Information

| Property | Value |
|----------|-------|
| **Name** | EU |
| **Context** | eu |
| **API Endpoint** | https://31.14.17.182:6443 |
| **K3s Version** | v1.32.5+k3s1 |
| **Nodes** | 2 (vps34-alwyzon-eu, vps36-alwyzon-eu) |
| **Storage** | Longhorn |
| **Ingress** | Traefik |
| **Certificate Manager** | cert-manager with Let's Encrypt |

## Nodes

| Node | Role | IP |
|------|------|-----|
| vps34-alwyzon-eu | Server (control-plane) | - |
| vps36-alwyzon-eu | Agent (worker) | - |

## Deployed Services

| Service | Namespace | Version | Documentation |
|---------|-----------|---------|---------------|
| Elasticsearch | elasticsearch | 8.17.0 | [ELASTICSEARCH.md](./ELASTICSEARCH.md) |
| Kibana | elasticsearch | 8.17.0 | [ELASTICSEARCH.md](./ELASTICSEARCH.md) |
| Prometheus | monitoring | Latest | [MONITORING.md](./MONITORING.md) |
| Grafana | monitoring | Latest | [MONITORING.md](./MONITORING.md) |
| Alertmanager | monitoring | Latest | [MONITORING.md](./MONITORING.md) |

## External Access

| Service | URL |
|---------|-----|
| Grafana | https://grafana.eu.k3s.canhnv.com |
| Kibana | https://kibana.eu.k3s.canhnv.com |

## Storage Classes

| Name | Replicas | Default |
|------|----------|---------|
| longhorn-replicated | 2 | No |
| longhorn-local | 1 | No |
| longhorn | 3 | Yes |

## Infrastructure

### ECK Operator

Elastic Cloud on Kubernetes (ECK) operator v2.16.1 is installed in the `elastic-system` namespace for managing Elasticsearch and Kibana deployments.

### Cert-Manager

Cert-manager is installed for automatic TLS certificate provisioning via Let's Encrypt:
- **ClusterIssuer**: `canhnv-com-prod` (production)
- **ClusterIssuer**: `canhnv-com-staging` (staging/testing)

### DNS & CDN

DNS records are managed through Cloudflare with proxy enabled for:
- DDoS protection
- CDN caching
- SSL/TLS termination

## Quick Commands

```bash
# Switch to EU context
kubectl config use-context eu

# Check cluster status
kubectl get nodes
kubectl get pods -A

# Check storage
kubectl get pvc -A

# Check certificates
kubectl get certificates -A
```

---

**Last Updated**: 2026-01-25
