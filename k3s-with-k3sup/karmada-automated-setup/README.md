# Karmada Multi-Cluster Automated Setup

This directory contains automated scripts to set up Karmada for managing multiple K3s clusters.

## Overview

Karmada (Kubernetes Armada) enables you to run cloud-native applications across multiple Kubernetes clusters with no changes to your applications. This setup will:

- Install Karmada control plane on Singapore (sg) cluster
- Join 5 production clusters: vn, vn2, us, eu, jp
- Deploy a test application showing cluster information
- Provide monitoring and management scripts

## Architecture

```
Singapore (sg) - Karmada Control Plane
├── Vietnam Primary (vn) - 3 master nodes + 1 worker
├── Vietnam Secondary (vn2) - 3 master nodes + 1 worker
├── United States (us) - 1 master + 1 worker
├── Europe (eu) - 1 master + 1 worker
└── Japan (jp) - 1 master + 1 worker

Excluded from Karmada:
- Development (dev) - Standalone cluster
- Singapore 2 (sg2) - Standalone cluster
```

## Prerequisites

- Access to all K3s clusters via kubectl
- SSH access to Singapore cluster (vps9)
- All clusters connected via WireGuard VPN
- kubectl installed on local machine

## Setup Steps

### Step 1: Export Kubeconfigs (On Local Machine)

```bash
# Make the script executable
chmod +x 01-export-kubeconfigs.sh

# Run the export script
./01-export-kubeconfigs.sh

# Transfer files to Singapore cluster
scp ~/karmada-kubeconfigs/kubeconfig-* root@46.250.232.0:/root/karmada-setup/configs/
```

### Step 2: Install Karmada (On vps9)

```bash
# SSH to Singapore cluster
ssh root@46.250.232.0

# Transfer and run setup script
cd /root
mkdir -p karmada-setup/scripts
# Copy 02-setup-karmada-host.sh to this location
chmod +x karmada-setup/scripts/02-setup-karmada-host.sh
./karmada-setup/scripts/02-setup-karmada-host.sh
```

### Step 3: Join Member Clusters (On vps9)

```bash
# Copy 03-join-clusters.sh to vps9
chmod +x /root/karmada-setup/scripts/03-join-clusters.sh
./karmada-setup/scripts/03-join-clusters.sh
```

### Step 4: Deploy Test Application (On vps9)

```bash
# Deploy nginx with cluster information display
chmod +x /root/karmada-setup/scripts/04-test-deployment-with-info.sh
./karmada-setup/scripts/04-test-deployment-with-info.sh
```

## Accessing the Test Application

The test deployment creates nginx pods that display cluster information. Each pod shows:

- Pod name and IP address
- Cluster name and geographic region
- Node information
- Real-time timestamp

### Method 1: Port Forwarding from vps9

```bash
# On vps9
/root/karmada-setup/scripts/access-nginx-clusters.sh
```

### Method 2: SSH Tunnels from Local Machine

```bash
# From your local machine
ssh -L 8001:localhost:8001 \
    -L 8002:localhost:8002 \
    -L 8003:localhost:8003 \
    -L 8004:localhost:8004 \
    -L 8005:localhost:8005 \
    root@46.250.232.0

# Then run the access script on vps9
```

Access URLs:

- <http://localhost:8001> → Vietnam Primary (vn)
- <http://localhost:8002> → Vietnam Secondary (vn2)
- <http://localhost:8003> → United States (us)
- <http://localhost:8004> → Europe (eu)
- <http://localhost:8005> → Japan (jp)

## Useful Commands

### Karmada Operations

```bash
# Switch to Karmada context
source /root/karmada-setup/scripts/karmada-context.sh karmada

# Check cluster status
kubectl karmada get clusters

# Check deployments across clusters
kubectl karmada get deploy -A

# Check specific cluster details
kubectl karmada cluster status vn
```

### Monitoring

```bash
# Check Karmada system status
/root/karmada-setup/scripts/check-karmada-status.sh

# Monitor nginx deployment
/root/karmada-setup/scripts/monitor-nginx-info.sh
```

### Cleanup

```bash
# Remove test deployment
kubectl --kubeconfig=/root/karmada-setup/configs/karmada-kubeconfig delete namespace karmada-test

# Unjoin a cluster
kubectl karmada unjoin <cluster-name>
```

## Propagation Policy

The default propagation policy distributes workloads based on weights:

- Vietnam clusters (vn, vn2): 30% each (3 replicas)
- US cluster: 20% (2 replicas)
- EU and JP clusters: 10% each (1 replica)

## Troubleshooting

### Cluster Join Issues

```bash
# Check cluster connectivity
nc -zv <cluster-ip> 6443

# Verify kubeconfig
kubectl --kubeconfig=/root/karmada-setup/configs/kubeconfig-<cluster> get nodes
```

### Pod Distribution Issues

```bash
# Check propagation policy
kubectl --kubeconfig=/root/karmada-setup/configs/karmada-kubeconfig describe propagationpolicy -n karmada-test

# Check resource bindings
kubectl --kubeconfig=/root/karmada-setup/configs/karmada-kubeconfig get rb -n karmada-test -o wide
```

### Karmada Component Issues

```bash
# Check Karmada pods
kubectl get pods -n karmada-system

# Check logs
kubectl logs -n karmada-system deployment/karmada-controller-manager
```

## Security Notes

- All cluster communication happens over WireGuard VPN (10.10.0.0/24)
- Karmada API is accessible via both internal and external IPs
- Each cluster maintains its own RBAC policies
- Secrets are not propagated by default

## Next Steps

1. Create custom propagation policies for your workloads
2. Set up multi-cluster services for cross-cluster communication
3. Configure failover policies for high availability
4. Integrate with existing monitoring solutions
5. Implement backup strategies for Karmada etcd

## Resources

- [Karmada Documentation](https://karmada.io/docs/)
- [Multi-cluster Patterns](https://karmada.io/docs/userguide/overview)
- [Policy Examples](https://github.com/karmada-io/karmada/tree/master/samples/policy)
