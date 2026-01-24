# Rancher Deployment - SG3 Cluster

## Overview

- **Version**: 2.11.2
- **Deployment Date**: 2025-11-25
- **Cluster**: SG3 (8 nodes: 3 control-plane, 5 workers)
- **Configuration**: 3 replicas (HA)

## Access

- **URL**: https://rancher.sg3.canhnv.com
- **Username**: admin
- **Bootstrap Password**: admin (change on first login)

**First-time setup URL**:
```bash
echo https://rancher.sg3.canhnv.com/dashboard/?setup=$(kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}')
```

## Configuration

- **Replicas**: 3 (high availability)
- **Resource Requests**: 500m CPU, 2Gi memory per pod
- **Resource Limits**: 2 CPU, 4Gi memory per pod
- **TLS**: Production certificate via cert-manager (canhnv-com-prod)
- **Anti-affinity**: preferred (replicas spread across nodes)
- **Ingress**: Traefik with TLS termination

## Deployment Status

**Deployed**: 2025-11-25

Components:
- rancher pods: 3 (DaemonSet-like distribution across nodes)
- TLS certificate: tls-rancher-ingress (Ready)
- Ingress: rancher.sg3.canhnv.com (Active)

## Operations

### Check Status

```bash
kubectl config use-context sg3
kubectl -n cattle-system get pods
kubectl -n cattle-system get ingress
kubectl -n cattle-system get certificate
```

### Get Bootstrap Password

```bash
kubectl get secret --namespace cattle-system bootstrap-secret \
  -o go-template='{{.data.bootstrapPassword|base64decode}}{{"\n"}}'
```

### Upgrade Rancher

```bash
helm upgrade rancher rancher-latest/rancher \
  --namespace cattle-system \
  --values /Users/canhnv/development/canhnv/k3s-ansible/apps/rancher/clusters/sg3/values.yaml \
  --version 2.11.2
```

### Uninstall

```bash
helm uninstall rancher -n cattle-system
kubectl delete namespace cattle-system
```

## Troubleshooting

### Check Pod Logs

```bash
kubectl -n cattle-system logs -l app=rancher --tail=100
```

### Check Ingress Configuration

```bash
kubectl -n cattle-system get ingress rancher -o yaml
```

### Certificate Issues

```bash
kubectl -n cattle-system describe certificate tls-rancher-ingress
kubectl -n cattle-system get certificaterequest
```

## Features

Rancher provides:
- **Cluster Management**: Monitor and manage sg3 cluster
- **Workload Management**: Deploy and manage applications
- **Storage Integration**: View and manage Longhorn volumes
- **RBAC**: User and permission management
- **Monitoring**: Built-in metrics and dashboards
- **App Catalog**: Deploy applications from catalog
- **Backup**: Rancher backup operator support

## First Login Steps

1. Navigate to https://rancher.sg3.canhnv.com
2. Login with username `admin` and password `admin`
3. Set a new secure password
4. Configure server URL (should auto-detect as rancher.sg3.canhnv.com)
5. Accept terms and conditions
6. Explore the cluster dashboard

## Integration

### Longhorn Integration

Rancher automatically detects Longhorn and provides:
- Storage class management
- Volume visualization
- PVC monitoring
- Storage capacity tracking

Access via: Cluster → Storage → Storage Classes / Persistent Volumes

### cert-manager Integration

Rancher uses the existing cert-manager setup:
- ClusterIssuer: canhnv-com-prod
- Auto-renewing TLS certificates
- Centralized certificate management

## Maintenance

### Regular Tasks
- Monitor pod health: `kubectl -n cattle-system get pods`
- Check resource usage: `kubectl top pods -n cattle-system`
- Review audit logs in Rancher UI
- Update Rancher version quarterly

### Backup Rancher Configuration
```bash
# Backup current configuration
kubectl -n cattle-system get all -o yaml > rancher-backup-$(date +%Y%m%d).yaml
```

For complete documentation, see [Main Rancher Documentation](../../README.md).
