# Karmada Multi-K3s Cluster Setup Plan

## Executive Summary

This document outlines the comprehensive plan for setting up Karmada to manage multiple K3s clusters. The Singapore (sg) cluster has been selected as the Karmada control plane host, managing 7 member clusters across different regions.

## Architecture Overview

### Cluster Fleet

- **Host Cluster**: Singapore (sg) - vps9 (10.10.0.9 / 46.250.232.0)
- **Member Clusters**:
  - Vietnam 1 (vn) - Control plane: vps22, vps23, vps24
  - Vietnam 2 (vn2) - Control plane: vps29, vps30, vps31
  - United States (us) - Control plane: vps26
  - Europe (eu) - Control plane: vps34
  - Japan (jp) - Control plane: vps3
  - Development (dev) - To be determined
  - Singapore 2 (sg2) - To be determined

### Network Architecture

- All clusters connected via WireGuard mesh (10.10.0.0/24)
- Each cluster has unique Pod and Service CIDRs to avoid conflicts
- API servers accessible via both internal (WireGuard) and external IPs

## Phase 1: Pre-Installation Checklist

### 1.1 Singapore Cluster Verification

```bash
# Check cluster health
kubectl config use-context sg
kubectl get nodes -o wide
kubectl top nodes

# Verify storage class
kubectl get storageclass

# Check current workloads
kubectl get pods -A
```

### 1.2 Network Connectivity Tests

```bash
# From vps9, test connectivity to all member clusters
for ip in 10.10.0.22 10.10.0.29 10.10.0.26 10.10.0.34 10.10.0.3; do
  echo "Testing connectivity to $ip"
  nc -zv $ip 6443
done
```

### 1.3 Resource Requirements

- Karmada Control Plane (on vps9):
  - CPU: 2 cores minimum (4 recommended)
  - Memory: 4GB minimum (8GB recommended)
  - Storage: 20GB for etcd and logs

## Phase 2: Karmada Installation

### 2.1 Install Karmada CLI

```bash
# SSH to Singapore control plane
ssh root@46.250.232.0

# Install karmadactl
curl -s https://raw.githubusercontent.com/karmada-io/karmada/master/hack/install-cli.sh | sudo INSTALL_CLI_VERSION=1.14.1 bash

# Verify installation
karmadactl version
```

### 2.2 Initialize Karmada Control Plane

#### Option A: Development/Testing Setup (Single Replica)

```bash
karmadactl init \
  --kubeconfig /etc/rancher/k3s/k3s.yaml \
  --namespace karmada-system \
  --etcd-storage-mode PVC \
  --storage-classes-name local-path \
  --etcd-replicas=1 \
  --karmada-apiserver-replicas=1 \
  --karmada-controller-manager-replicas=1 \
  --karmada-scheduler-replicas=1 \
  --karmada-webhook-replicas=1 \
  --cert-external-ip=10.10.0.9,46.250.232.0 \
  --cert-external-dns=vps9.canhnv.com,sg.karmada.canhnv.com
```

#### Option B: Production Setup (HA Mode)

```bash
karmadactl init \
  --kubeconfig /etc/rancher/k3s/k3s.yaml \
  --namespace karmada-system \
  --etcd-storage-mode PVC \
  --storage-classes-name local-path \
  --etcd-replicas=3 \
  --karmada-apiserver-replicas=2 \
  --karmada-controller-manager-replicas=2 \
  --karmada-scheduler-replicas=2 \
  --karmada-webhook-replicas=2 \
  --cert-external-ip=10.10.0.9,46.250.232.0 \
  --cert-external-dns=vps9.canhnv.com,sg.karmada.canhnv.com
```

### 2.3 Verify Karmada Installation

```bash
# Check Karmada components
kubectl get pods -n karmada-system

# Get Karmada API server info
kubectl get svc -n karmada-system karmada-apiserver

# Test Karmada API
kubectl karmada get clusters
```

## Phase 3: Member Cluster Integration

### 3.1 Prepare Kubeconfig Files

Create directory structure:

```bash
mkdir -p /root/karmada-setup/kubeconfigs
cd /root/karmada-setup
```

### 3.2 Update Ansible Configuration

Update the inventory and scripts in the local environment before copying to vps9.

### 3.3 Join Member Clusters

For each member cluster:

```bash
# Example for VN cluster
kubectl karmada join vn \
  --cluster-kubeconfig=/root/karmada-setup/kubeconfigs/config-vn \
  --cluster-context=vn \
  --cluster-namespace=karmada-cluster-vn

# Repeat for other clusters: vn2, jp, eu, us, dev
```

### 3.4 Verify Cluster Registration

```bash
# List all registered clusters
kubectl karmada get clusters

# Check specific cluster status
kubectl karmada cluster status vn
```

## Phase 4: Multi-Cluster Configuration

### 4.1 Resource Aggregation

Enable resource aggregation for unified view:

```bash
kubectl apply -f - <<EOF
apiVersion: cluster.karmada.io/v1alpha1
kind: ResourceInterpreterWebhookConfiguration
metadata:
  name: examples
webhooks:
  - name: workloads.example.com
    rules:
      - apiGroups: ["apps"]
        apiVersions: ["v1"]
        kinds: ["Deployment", "StatefulSet"]
        operations: ["InterpretReplica", "AggregateStatus"]
EOF
```

### 4.2 Create Cluster Labels

Label clusters for easier policy targeting:

```bash
# Geographic regions
kubectl karmada label cluster vn region=vietnam tier=production
kubectl karmada label cluster vn2 region=vietnam tier=production
kubectl karmada label cluster us region=americas tier=production
kubectl karmada label cluster eu region=europe tier=production
kubectl karmada label cluster jp region=asia-pacific tier=production
kubectl karmada label cluster dev region=vietnam tier=development

# Capabilities
kubectl karmada label cluster vn capabilities=storage
kubectl karmada label cluster vn2 capabilities=compute
```

### 4.3 Configure Multi-Cluster Networking

Create MultiClusterService for cross-cluster communication:

```bash
kubectl apply -f - <<EOF
apiVersion: networking.karmada.io/v1alpha1
kind: MultiClusterIngress
metadata:
  name: cross-cluster-ingress
  namespace: default
spec:
  ingressClassName: traefik
  rules:
    - host: app.multi-cluster.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
EOF
```

## Phase 5: Workload Distribution Policies

### 5.1 Basic Propagation Policy

Create a policy to distribute workloads across regions:

```bash
kubectl apply -f - <<EOF
apiVersion: policy.karmada.io/v1alpha1
kind: PropagationPolicy
metadata:
  name: nginx-propagation
  namespace: default
spec:
  resourceSelectors:
    - apiVersion: apps/v1
      kind: Deployment
      name: nginx
  placement:
    clusterAffinity:
      clusterNames:
        - vn
        - us
        - eu
    replicaScheduling:
      replicaDivisionPreference: Weighted
      replicaSchedulingType: Divided
      weightPreference:
        staticWeightList:
          - targetCluster:
              clusterNames:
                - vn
            weight: 2
          - targetCluster:
              clusterNames:
                - us
            weight: 1
          - targetCluster:
              clusterNames:
                - eu
            weight: 1
EOF
```

### 5.2 Failover Policy

Configure automatic failover between clusters:

```bash
kubectl apply -f - <<EOF
apiVersion: policy.karmada.io/v1alpha1
kind: PropagationPolicy
metadata:
  name: failover-policy
  namespace: default
spec:
  resourceSelectors:
    - apiVersion: apps/v1
      kind: Deployment
  placement:
    clusterAffinity:
      clusterNames:
        - vn
        - vn2
    failover:
      application:
        decisionConditions:
          tolerationSeconds: 30
EOF
```

## Phase 6: Monitoring and Observability

### 6.1 Deploy Karmada Metrics Adapter

```bash
helm install karmada-metrics-adapter \
  charts/karmada-metrics-adapter \
  --namespace karmada-system \
  --set apiService.insecureSkipTLSVerify=true
```

### 6.2 Configure Prometheus Federation

Deploy Prometheus in Singapore cluster to collect metrics from all clusters:

```yaml
# prometheus-federation.yaml
global:
  scrape_interval: 15s
  external_labels:
    cluster: 'karmada-host'

scrape_configs:
  - job_name: 'federate'
    scrape_interval: 15s
    honor_labels: true
    metrics_path: '/federate'
    params:
      'match[]':
        - '{job=~".*"}'
    static_configs:
      - targets:
        - 'vn-prometheus.vn.svc.cluster.local:9090'
        - 'us-prometheus.us.svc.cluster.local:9090'
        - 'eu-prometheus.eu.svc.cluster.local:9090'
```

## Phase 7: Backup and Disaster Recovery

### 7.1 Backup Karmada etcd

```bash
# Create backup script
cat > /root/karmada-backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/root/karmada-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

# Backup etcd
kubectl exec -n karmada-system etcd-0 -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /tmp/snapshot.db

kubectl cp karmada-system/etcd-0:/tmp/snapshot.db \
  $BACKUP_DIR/etcd-snapshot-$TIMESTAMP.db
EOF

chmod +x /root/karmada-backup.sh

# Schedule daily backups
echo "0 2 * * * /root/karmada-backup.sh" | crontab -
```

### 7.2 Disaster Recovery Plan

1. **Control Plane Failure**:
   - Restore from etcd backup
   - Reinitialize Karmada if necessary
   - Rejoin member clusters

2. **Member Cluster Failure**:
   - Karmada automatically detects unhealthy clusters
   - Workloads failover based on policies
   - Manual intervention for stateful workloads

## Phase 8: Operational Procedures

### 8.1 Adding New Clusters

```bash
# 1. Prepare kubeconfig
kubectl config view --minify --flatten --context=newcluster > config-newcluster

# 2. Join to Karmada
kubectl karmada join newcluster \
  --cluster-kubeconfig=config-newcluster \
  --cluster-context=newcluster

# 3. Label the cluster
kubectl karmada label cluster newcluster region=<region> tier=<tier>
```

### 8.2 Removing Clusters

```bash
# 1. Migrate workloads
kubectl karmada get deployments --cluster=oldcluster

# 2. Unjoin cluster
kubectl karmada unjoin oldcluster

# 3. Clean up resources
kubectl delete cluster oldcluster
```

### 8.3 Upgrading Karmada

```bash
# 1. Backup current state
./karmada-backup.sh

# 2. Upgrade Karmada
karmadactl upgrade --kubeconfig=/etc/rancher/k3s/k3s.yaml

# 3. Verify upgrade
kubectl karmada version
```

## Troubleshooting Guide

### Common Issues

1. **Cluster Join Fails**
   - Check network connectivity
   - Verify kubeconfig validity
   - Check Karmada API server logs

2. **Workload Not Propagating**
   - Verify PropagationPolicy matches resources
   - Check cluster health status
   - Review Karmada controller logs

3. **Cross-Cluster Communication Issues**
   - Verify WireGuard mesh connectivity
   - Check MultiClusterService configuration
   - Review DNS resolution

### Debug Commands

```bash
# Check Karmada logs
kubectl logs -n karmada-system deployment/karmada-controller-manager

# Check cluster status
kubectl get cluster -o yaml

# Debug propagation
kubectl describe propagationpolicy <policy-name>
```

## Maintenance Schedule

- **Daily**: Automated etcd backups
- **Weekly**: Review cluster health and resource usage
- **Monthly**: Update Karmada and review policies
- **Quarterly**: Disaster recovery drills

## Security Considerations

1. **API Access**: All Karmada API access over WireGuard VPN
2. **RBAC**: Implement least-privilege access
3. **Secrets**: Use Kubernetes secrets for sensitive data
4. **Network Policies**: Restrict inter-cluster traffic
5. **Audit Logging**: Enable for compliance

## Next Steps

1. Execute Phase 1-3 for basic setup
2. Test with simple workloads
3. Gradually migrate existing workloads
4. Implement monitoring and alerting
5. Document specific use cases and patterns
