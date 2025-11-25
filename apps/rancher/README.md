# Rancher Deployment

Rancher is a complete container management platform for Kubernetes, providing cluster management, monitoring, and multi-cluster operations.

## Overview

- **Chart**: rancher/rancher
- **Version**: 2.11.2
- **Namespace**: cattle-system

## Cluster Deployments

### Development Cluster

- **Context**: `dev`
- **Hostname**: `dev.k3s.canhnv.com`
- **Replicas**: 1 (scaled down due to pod stability issues)
- **Configuration**: [clusters/dev/values.yaml](./clusters/dev/values.yaml)

### SG3 Cluster

- **Context**: `sg3`
- **Hostname**: `rancher.sg3.canhnv.com`
- **Replicas**: 3 (HA configuration)
- **Configuration**: [clusters/sg3/values.yaml](./clusters/sg3/values.yaml)

## Installation

### Prerequisites

1. **Add Rancher Helm repository**:
   ```bash
   helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
   helm repo update
   ```

2. **Create namespace**:
   ```bash
   kubectl create namespace cattle-system
   ```

3. **Install cert-manager** (if not already installed):
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   ```

### Initial Installation

```bash
# Switch to target cluster
kubectl config use-context dev

# Install Rancher with custom values
helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --values apps/rancher/clusters/dev/values.yaml \
  --version 2.11.2
```

## Upgrade

To upgrade Rancher or apply configuration changes:

```bash
# Switch to target cluster
kubectl config use-context dev

# Upgrade with custom values
helm upgrade rancher rancher-latest/rancher \
  --namespace cattle-system \
  --values apps/rancher/clusters/dev/values.yaml \
  --version 2.11.2
```

## Applying Replica Changes

If you've manually scaled the deployment and want to persist the change:

1. **Update values file**: Edit `clusters/dev/values.yaml` and set `replicas: 1`

2. **Apply changes via Helm**:
   ```bash
   kubectl config use-context dev
   helm upgrade rancher rancher-latest/rancher \
     --namespace cattle-system \
     --values apps/rancher/clusters/dev/values.yaml \
     --reuse-values
   ```

## Accessing Rancher

### Development Cluster

- **UI**: https://dev.k3s.canhnv.com/dashboard/
- **API**: https://dev.k3s.canhnv.com
- **Username**: `admin`
- **Password**: Set via `bootstrapPassword` in values.yaml (default: `admin`)

### First Login

On first login, Rancher will prompt you to:
1. Set a new admin password
2. Configure the Rancher server URL
3. Accept terms and conditions

## Configuration

### Key Values

- `replicas`: Number of Rancher pods (default: 3, dev: 1)
- `hostname`: DNS hostname for accessing Rancher
- `bootstrapPassword`: Initial admin password
- `ingress.tls.source`: TLS certificate source (letsEncrypt, secret, rancher)
- `resources`: CPU and memory limits/requests

### Resource Requirements

Recommended resources per replica:
- **CPU**: 500m request, 2000m limit
- **Memory**: 2Gi request, 4Gi limit

For production clusters with 3 replicas, ensure adequate node resources.

## Troubleshooting

### Pods in CrashLoopBackOff

If Rancher pods are crashing:

1. **Check pod logs**:
   ```bash
   kubectl logs -n cattle-system <pod-name> --tail=100
   ```

2. **Check resource usage**:
   ```bash
   kubectl top pods -n cattle-system
   kubectl top nodes
   ```

3. **Scale down to 1 replica**:
   ```bash
   kubectl scale deployment -n cattle-system rancher --replicas=1
   ```

4. **Add resource limits** in values.yaml and upgrade via Helm

### UI Returns 404

- Ensure you're accessing `/dashboard/` path: https://hostname/dashboard/
- Check ingress configuration:
  ```bash
  kubectl get ingress -n cattle-system rancher -o yaml
  ```

### Certificate Issues

- Verify cert-manager is running:
  ```bash
  kubectl get pods -n cert-manager
  ```

- Check certificate status:
  ```bash
  kubectl get certificate -n cattle-system
  kubectl describe certificate -n cattle-system tls-rancher-ingress
  ```

## Uninstallation

```bash
# Switch to target cluster
kubectl config use-context dev

# Uninstall Rancher
helm uninstall rancher -n cattle-system

# Clean up namespace (optional)
kubectl delete namespace cattle-system
```

**Warning**: Uninstalling Rancher will not automatically clean up resources it created. Follow [Rancher's official cleanup guide](https://rancher.com/docs/rancher/v2.x/en/system-tools/) for complete removal.

## References

- [Rancher Documentation](https://rancher.com/docs/rancher/v2.x/en/)
- [Rancher Helm Chart](https://github.com/rancher/rancher/tree/main/chart)
- [Installation Guide](https://rancher.com/docs/rancher/v2.x/en/installation/install-rancher-on-k8s/)
