# SG3 Cluster - Singapore OVH

## Overview

The SG3 cluster is a production K3s cluster running on OVH cloud infrastructure in Singapore. It features a high-availability setup with 3 control plane nodes and 5 worker nodes, all interconnected via Wireguard mesh network for secure communication.

**Created**: November 24, 2025
**Provider**: OVH Cloud
**Region**: Singapore (Asia-Pacific)
**K3s Version**: v1.32.5+k3s1
**Setup Method**: k3sup

## Cluster Architecture

### Control Plane Nodes (3)

| Hostname | Wireguard IP | Public IP | Role | Hardware |
|----------|--------------|-----------|------|----------|
| vps-44781858 (vps51) | 10.10.0.51 | 15.235.211.39 | Master 1 | Ubuntu 24.04.3 LTS |
| vps-4f55f951 (vps52) | 10.10.0.52 | 15.235.197.174 | Master 2 | Ubuntu 24.04.3 LTS |
| vps-7bdd470c (vps54) | 10.10.0.54 | 15.235.197.175 | Master 3 | Ubuntu 24.04.3 LTS |

### Worker Nodes (5)

| Hostname | Wireguard IP | Public IP | Role | Hardware |
|----------|--------------|-----------|------|----------|
| vps-01cb6324 (vps50) | 10.10.0.50 | 15.235.197.155 | Worker | Ubuntu 24.04.3 LTS |
| vps-71eb1712 (vps53) | 10.10.0.53 | 15.235.197.12 | Worker | Ubuntu 24.04.3 LTS |
| vps-ad357b71 (vps55) | 10.10.0.55 | 15.235.197.207 | Worker | Ubuntu 24.04.3 LTS |
| vps-b623746f (vps56) | 10.10.0.56 | 15.235.211.111 | Worker | Ubuntu 24.04.3 LTS |
| vps-d81b042b (vps57) | 10.10.0.57 | 15.235.197.222 | Worker | Ubuntu 24.04.3 LTS |

## Network Configuration

### Pod and Service Networks

- **Pod CIDR**: 10.54.0.0/16
- **Service CIDR**: 10.55.0.0/16
- **Cluster DNS**: 10.55.0.10

### Wireguard Mesh Network

All nodes are connected via Wireguard VPN mesh network:
- **Interface**: wg0
- **Network**: 10.10.0.0/24
- **Node IPs**: 10.10.0.50-57
- **Port**: 51820/udp

Pod networking uses Flannel over the Wireguard interface (`--flannel-iface=wg0`), ensuring all pod-to-pod communication is encrypted.

## Access

### Kubectl Access

```bash
# Switch to sg3 cluster context
kubectl config use-context sg3

# Verify access
kubectl get nodes

# Get cluster info
kubectl cluster-info
```

### API Endpoint

- **Primary API**: <https://15.235.211.39:6443>
- **Accessible from**: Any location with proper kubeconfig and authentication

### SSH Access

All nodes are accessible via SSH using the `ubuntu` user and the `canhnv_vps` SSH key:

```bash
# Control plane nodes
ssh -i ~/.ssh/canhnv_vps ubuntu@15.235.211.39  # vps51 (master 1)
ssh -i ~/.ssh/canhnv_vps ubuntu@15.235.197.174 # vps52 (master 2)
ssh -i ~/.ssh/canhnv_vps ubuntu@15.235.197.175 # vps54 (master 3)

# Worker nodes
ssh -i ~/.ssh/canhnv_vps ubuntu@15.235.197.155 # vps50
ssh -i ~/.ssh/canhnv_vps ubuntu@15.235.197.12  # vps53
ssh -i ~/.ssh/canhnv_vps ubuntu@15.235.197.207 # vps55
ssh -i ~/.ssh/canhnv_vps ubuntu@15.235.211.111 # vps56
ssh -i ~/.ssh/canhnv_vps ubuntu@15.235.197.222 # vps57
```

## High Availability

The cluster is configured for high availability:

- **3 Control Plane Nodes**: Provides quorum and can tolerate 1 node failure
- **Embedded etcd**: Running in HA mode across all control plane nodes
- **Load Balancing**: Kubernetes API requests are distributed across all control plane nodes
- **Automatic Failover**: If one control plane node fails, the other two continue serving requests

## Setup Commands

The cluster was set up using k3sup with the following commands:

### Initial Master Setup

```bash
./k3sup-darwin-arm64 install \
  --ip 15.235.211.39 \
  --user ubuntu \
  --ssh-key ~/.ssh/canhnv_vps \
  --cluster \
  --k3s-version v1.32.5+k3s1 \
  --k3s-extra-args '--flannel-iface=wg0 --advertise-address=10.10.0.51 --tls-san=10.10.0.51 --tls-san=15.235.211.39 --node-label=region=sg3 --node-ip=10.10.0.51 --node-external-ip=15.235.211.39 --cluster-cidr=10.54.0.0/16 --service-cidr=10.55.0.0/16 --cluster-dns=10.55.0.10'
```

### Additional Masters

```bash
# Second master (vps52)
./k3sup-darwin-arm64 join \
  --ip 15.235.197.174 \
  --user ubuntu \
  --server-user ubuntu \
  --server-ip 15.235.211.39 \
  --server \
  --k3s-version v1.32.5+k3s1 \
  --ssh-key ~/.ssh/canhnv_vps \
  --k3s-extra-args '--flannel-iface=wg0 --advertise-address=10.10.0.52 --tls-san=10.10.0.52 --tls-san=15.235.197.174 --node-label=region=sg3 --node-ip=10.10.0.52 --node-external-ip=15.235.197.174 --cluster-cidr=10.54.0.0/16 --service-cidr=10.55.0.0/16 --cluster-dns=10.55.0.10'

# Third master (vps54)
./k3sup-darwin-arm64 join \
  --ip 15.235.197.175 \
  --user ubuntu \
  --server-user ubuntu \
  --server-ip 15.235.211.39 \
  --server \
  --k3s-version v1.32.5+k3s1 \
  --ssh-key ~/.ssh/canhnv_vps \
  --k3s-extra-args '--flannel-iface=wg0 --advertise-address=10.10.0.54 --tls-san=10.10.0.54 --tls-san=15.235.197.175 --node-label=region=sg3 --node-ip=10.10.0.54 --node-external-ip=15.235.197.175 --cluster-cidr=10.54.0.0/16 --service-cidr=10.55.0.0/16 --cluster-dns=10.55.0.10'
```

### Worker Nodes

```bash
# Example for vps50 (repeat for other workers)
./k3sup-darwin-arm64 join \
  --ip 15.235.197.155 \
  --user ubuntu \
  --server-user ubuntu \
  --server-ip 15.235.211.39 \
  --k3s-version v1.32.5+k3s1 \
  --ssh-key ~/.ssh/canhnv_vps \
  --k3s-extra-args '--flannel-iface=wg0 --node-label=region=sg3 --node-ip=10.10.0.50 --node-external-ip=15.235.197.155'
```

## Verification

### Check Cluster Health

```bash
# Check all nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods -A

# Verify networking
kubectl run test-pod --image=nginx --restart=Never
kubectl exec test-pod -- curl -I localhost
kubectl delete pod test-pod
```

### Verify Wireguard Connectivity

```bash
# SSH to any node and check Wireguard status
ssh -i ~/.ssh/canhnv_vps ubuntu@15.235.211.39 "sudo wg show"

# Test connectivity between nodes
ssh -i ~/.ssh/canhnv_vps ubuntu@15.235.211.39 "ping -c 3 10.10.0.50"
```

## Maintenance

### Upgrading K3s

To upgrade the K3s version:

1. Upgrade control plane nodes one at a time:
   ```bash
   ssh -i ~/.ssh/canhnv_vps ubuntu@15.235.211.39
   curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=vX.XX.X+k3s1 sh -
   ```

2. Upgrade worker nodes:
   ```bash
   ssh -i ~/.ssh/canhnv_vps ubuntu@15.235.197.155
   curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=vX.XX.X+k3s1 K3S_URL=https://15.235.211.39:6443 K3S_TOKEN=<token> sh -
   ```

### Restarting K3s Services

```bash
# On control plane nodes
sudo systemctl restart k3s

# On worker nodes
sudo systemctl restart k3s-agent
```

### Troubleshooting Wireguard

If Wireguard connectivity issues occur:

```bash
# Check Wireguard status
sudo wg show

# Restart Wireguard
sudo systemctl restart wg-quick@wg0

# Check if interface is up
ip addr show wg0

# Test connectivity
ping 10.10.0.51
```

## Security Considerations

- All pod-to-pod traffic is encrypted via Wireguard mesh network
- SSH access requires private key authentication (no password login)
- API server uses TLS certificates for secure communication
- Firewall rules should limit access to:
  - Port 6443 (Kubernetes API) - restricted to trusted IPs
  - Port 51820/udp (Wireguard) - allow between all cluster nodes
  - Port 22 (SSH) - restricted to management IPs

## Node Labels

All nodes are labeled with `region=sg3` for workload scheduling:

```bash
# Schedule workloads to sg3 cluster
kubectl run my-app --image=my-app:latest --node-selector region=sg3
```

## Related Documentation

- [Clusters Overview](../../CLUSTERS_OVERVIEW.md)
- [Infrastructure Guide](../../INFRASTRUCTURE.md)
- [Wireguard Ansible Setup](../../../k3s-with-k3sup/wireguard-ansible/README.md)
- [k3sup Documentation](../../../k3s-with-k3sup/README.md)

## Change Log

- **2025-11-24**: Initial cluster setup with 3 control plane nodes and 5 worker nodes
  - Configured Wireguard mesh network (10.10.0.50-57)
  - Set up K3s v1.32.5+k3s1 with HA embedded etcd
  - Configured pod networking with Flannel over Wireguard
  - Verified pod-to-pod communication across nodes

## TLS Certificate Management

### cert-manager Installation

The cluster uses cert-manager for automated TLS certificate provisioning with Let's Encrypt.

**Install cert-manager**:
```bash
cd tls-certificates/clusters/sg3
./install-cert-manager.sh
```

**Install ClusterIssuers**:
```bash
./install-issuers.sh
```

### Available ClusterIssuers

After installation, the following ClusterIssuers are available:

1. **canhnv.com**:
   - `canhnv-com-staging` - Let's Encrypt staging (for testing)
   - `canhnv-com-prod` - Let's Encrypt production

2. **ambercare-app (murror.app)**:
   - `ambercare-app-staging` - Let's Encrypt staging
   - `ambercare-app` - Let's Encrypt production

### Usage in Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  annotations:
    cert-manager.io/cluster-issuer: "canhnv-com-prod"
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - app.canhnv.com
    secretName: app-tls
  rules:
  - host: app.canhnv.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-service
            port:
              number: 80
```

### Verification

```bash
# Check ClusterIssuers
kubectl get clusterissuer

# Check certificates
kubectl get certificate -A

# Check cert-manager logs
kubectl logs -n cert-manager deploy/cert-manager -f
```

See [TLS Certificates Management](../../../tls-certificates/README.md) for detailed documentation.

## Storage Management

### Longhorn Distributed Storage

**Version**: 1.9.1
**Namespace**: longhorn-system
**Web UI**: https://sg3.longhorn.canhnv.com

#### Configuration
- **Replica Count**: 3 (distributed across nodes)
- **CSI Components**: 3 replicas each for HA
- **UI Replicas**: 2 for high availability
- **Deployment Date**: 2025-11-25

#### Storage Classes

| Storage Class | Replicas | Reclaim Policy | Use Case |
|---------------|----------|----------------|----------|
| longhorn (default) | 3 | Retain | General purpose |
| longhorn-retain | 3 | Retain | Important data |
| longhorn-fast | 2 | Delete | Performance-sensitive |
| longhorn-single | 1 | Delete | Non-critical data |

#### Usage Example

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-data
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: 10Gi
```

#### Operations

```bash
# Deploy Longhorn
make deploy-sg3

# Check status
make status-sg3

# Access UI
open https://sg3.longhorn.canhnv.com
```

See [Longhorn SG3 Documentation](../../../longhorn/clusters/sg3/README.md) for detailed information.

## Cluster Management

### Rancher

**Version**: 2.11.2
**Namespace**: cattle-system
**Web UI**: https://rancher.sg3.canhnv.com

Rancher provides a web-based UI for managing the sg3 cluster, including:
- Cluster monitoring and metrics
- Workload management
- Storage management (Longhorn integration)
- RBAC and user management
- Application catalog

**Access**:
```bash
# Get bootstrap password
kubectl get secret --namespace cattle-system bootstrap-secret \
  -o go-template='{{.data.bootstrapPassword|base64decode}}{{"\n"}}'

# Access UI
open https://rancher.sg3.canhnv.com
```

**First login**: Username `admin`, Password `admin` (will be prompted to change)

See [Rancher SG3 Documentation](../../../apps/rancher/clusters/sg3/README.md) for details.

## Monitoring Stack

### Prometheus and Grafana

**Deployed**: November 25, 2025
**Namespace**: monitoring
**Helm Chart**: kube-prometheus-stack

#### Components

- **Prometheus**: Metrics collection and time-series storage
- **Grafana**: Visualization and dashboards
- **Alertmanager**: Alert routing and management
- **Node Exporter**: System metrics from all 8 nodes
- **kube-state-metrics**: Kubernetes object metrics
- **Prometheus Operator**: CRD management

#### Storage Configuration

All monitoring data uses **Longhorn distributed storage** with 3 replicas for high availability:

| Component | Storage | Storage Class | Retention |
|-----------|---------|---------------|-----------|
| Prometheus | 25Gi | longhorn | 15 days |
| Grafana | 25Gi | longhorn | Persistent |
| Alertmanager | 25Gi | longhorn | Persistent |

**Total**: 75Gi logical (225Gi raw with replication)

#### Access Information

**Grafana**:
- URL: https://grafana.sg3.k3s.canhnv.com
- Username: `admin`
- Get password:
  ```bash
  kubectl get secret -n monitoring kube-prometheus-stack-grafana \
    -o jsonpath="{.data.admin-password}" | base64 -d && echo
  ```

**Prometheus**:
- External URL: https://prometheus.sg3.k3s.canhnv.com
- Port forward:
  ```bash
  kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
  ```

**Alertmanager**:
- Port forward:
  ```bash
  kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
  ```

#### Monitored Services

The monitoring stack automatically collects metrics from:
- All 8 cluster nodes (CPU, memory, disk, network)
- Kubernetes components (API server, kubelet, CoreDNS)
- Longhorn storage system (volume health, performance)
- Rancher management plane
- All deployed applications with ServiceMonitor labels

#### Operations

```bash
# Check monitoring stack status
kubectl get pods -n monitoring

# Verify PVCs
kubectl get pvc -n monitoring

# Check Longhorn volumes
kubectl get volumes -n longhorn-system | grep monitoring

# View logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```

See [Monitoring SG3 Documentation](../../../monitoring/clusters/sg3/README.md) for detailed information.
