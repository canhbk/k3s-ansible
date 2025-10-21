# VN2 Cluster (Vietnam Secondary)

## Overview

The VN2 cluster is a production K3s cluster deployed in Vietnam, serving as the secondary Vietnam cluster for high availability and workload distribution.

**Last Updated**: 2025-10-21

## Cluster Information

- **Context Name**: `vn2`
- **API Endpoint**: `https://163.61.73.78:6443`
- **K3s Version**: `v1.32.5+k3s1`
- **Environment**: Production
- **Region**: Vietnam (vn2)
- **Default Namespace**: `nsp-prod-murror`

## Infrastructure

### Control Plane Nodes (3)

| Hostname | Wireguard IP | External IP | Role | Status |
|----------|--------------|-------------|------|--------|
| vps29-bnix | 10.10.0.29 | 163.61.73.78 | control-plane, etcd, master | Ready |
| vps30-bnix | 10.10.0.30 | 163.61.73.79 | control-plane, etcd, master | Ready |
| vps31-bnix | 10.10.0.31 | 163.61.73.90 | control-plane, etcd, master | Ready |

### Agent Nodes (1)

| Hostname | Wireguard IP | External IP | Role | Status | Added |
|----------|--------------|-------------|------|--------|-------|
| vps28-bnix | 10.10.0.28 | 163.61.73.77 | agent | Ready | 2025-10-21 |

## Network Configuration

### Cluster Network

- **Cluster CIDR**: `10.44.0.0/16`
- **Service CIDR**: `10.45.0.0/16`
- **Cluster DNS**: `10.45.0.10`
- **Flannel Interface**: `wg0` (Wireguard)
- **Backend**: VXLAN

### Wireguard VPN

All nodes communicate over a Wireguard VPN mesh on the `wg0` interface:
- Private network: `10.10.0.0/24`
- All K3s traffic routed through Wireguard for security

## Deployment Method

This cluster was deployed manually using the k3s install script (not Ansible).

See: `k3s-with-k3sup/manual.md` for deployment commands and cluster setup history.

### Initial Setup (Historical)

The cluster was initialized on vps29-bnix with:
```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.32.5+k3s1 \
  INSTALL_K3S_EXEC="server --cluster-init --cluster-cidr=10.44.0.0/16 \
  --service-cidr=10.45.0.0/16 --cluster-dns=10.45.0.10 --flannel-iface=wg0 \
  --advertise-address=10.10.0.29 --tls-san=10.10.0.29 --tls-san=163.61.73.78 \
  --tls-san=vps29.canhnv.com --node-label=region=vn2 --node-ip=10.10.0.29 \
  --node-external-ip=163.61.73.78 --node-external-dns=vps29.canhnv.com" sh -
```

## Key Services

- **Primary Use**: Murror production workloads
- **Service Mesh**: Traefik ingress controller (default)
- **Load Balancing**: svclb (K3s Service Load Balancer)

## Access

### Kubectl Context

```bash
# Switch to vn2 cluster
kubectl config use-context vn2

# Verify access
kubectl get nodes -o wide

# Check running pods
kubectl get pods -A
```

### SSH Access

All nodes are accessible via SSH as root user. Credentials are stored in:
- `k3s-with-k3sup/wireguard-ansible/inventory/hosts.local.yaml`

## Common Operations

### Check Cluster Health

```bash
kubectl config use-context vn2
kubectl get nodes
kubectl get pods -A
kubectl top nodes
```

### Add New Agent Node

1. Ensure the node has Wireguard configured and can reach control plane nodes
2. Run the agent join command (see manual.md)
3. Verify node joined: `kubectl get nodes`
4. Update this documentation

### Remove Agent Node

1. Cordon the node: `kubectl cordon <node-name>`
2. Drain the node: `kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data`
3. SSH to node and uninstall: `/usr/local/bin/k3s-agent-uninstall.sh`
4. Delete from cluster: `kubectl delete node <node-name>`
5. Update this documentation

## Troubleshooting

### Pod Network Connectivity Issues

If pods on different nodes cannot communicate:

1. Check Wireguard connectivity between nodes
2. Verify flannel is running: `kubectl get pods -n kube-system | grep flannel`
3. Restart K3s services if needed (see CLAUDE.md troubleshooting section)

### Node Not Ready

1. SSH to the node
2. Check K3s service: `systemctl status k3s-agent`
3. Check logs: `journalctl -u k3s-agent -f`
4. Verify Wireguard: `wg show`

## Change History

| Date | Change | Notes |
|------|--------|-------|
| 2025-10-21 | Added vps28-bnix as agent node | Previous networking issues resolved, node rejoined cluster |
| 2024-09-24 | Removed vps28-bnix | Due to networking issues |

## Related Documentation

- [Clusters Overview](../../CLUSTERS_OVERVIEW.md)
- [Manual K3s Setup Guide](../../../k3s-with-k3sup/manual.md)
- [Security Guidelines](../../SECURITY_GUIDELINES.md)
