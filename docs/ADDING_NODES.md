# Adding Nodes to K3s Clusters

This guide explains how to add new nodes to existing K3s clusters managed by this Ansible playbook.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Adding Agent (Worker) Nodes](#adding-agent-worker-nodes)
- [Adding Server (Control Plane) Nodes](#adding-server-control-plane-nodes)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Advanced Scenarios](#advanced-scenarios)

## Prerequisites

Before adding any new nodes to your K3s cluster, ensure the following requirements are met:

### System Requirements

- **Operating System**: One of the following:
  - Debian (9+)
  - Ubuntu (18.04+)
  - Raspberry Pi OS
  - RHEL Family (CentOS 7+, RHEL 7+, Rocky Linux 8+)
  - SUSE Family (SLES 15+, OpenSUSE Leap 15+)
  - ArchLinux

- **Architecture**: x64, arm64, or armhf

### Network Requirements

- **SSH Access**: Passwordless SSH access from the Ansible control node
- **Network Connectivity**:
  - Ability to reach the K3s server node(s) on port 6443
  - Open required ports (see below)
- **DNS/Hostname Resolution**: Nodes should be able to resolve each other

### Required Ports

| Protocol | Port | Description |
|----------|------|-------------|
| TCP | 6443 | Kubernetes API Server |
| TCP | 2379-2380 | etcd server client API (HA only) |
| TCP | 2381 | etcd metrics |
| UDP | 8472 | Flannel VXLAN |
| TCP | 10250 | Kubelet metrics |
| TCP | 5001 | Embedded registry |
| UDP | 51820-51821 | WireGuard (if used) |

### System Configuration

- **Swap**: Should be disabled (recommended)
- **Firewall**: Should be disabled or properly configured
- **SELinux**: Should be in permissive mode or properly configured

## Adding Agent (Worker) Nodes

Agent nodes are worker nodes that run your application workloads. They don't participate in cluster management decisions.

### Step 1: Prepare the New Node

On the new node, ensure:

```bash
# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Disable firewall (or configure it properly)
# For Ubuntu/Debian:
sudo ufw disable

# For RHEL/CentOS:
sudo systemctl disable firewalld
sudo systemctl stop firewalld
```

### Step 2: Update Inventory File

Edit your inventory file (e.g., `inventory.dev.local.yml`, `inventory.prod.yml`):

```yaml
k3s_cluster:
  children:
    server:
      hosts:
        # Existing server nodes
        192.168.1.10:
          ansible_user: root
          ansible_ssh_pass: server_password
    agent:
      hosts:
        # Existing agent nodes
        192.168.1.20:
          ansible_user: root
          ansible_ssh_pass: agent1_password

        # ADD YOUR NEW NODE HERE
        192.168.1.30:
          ansible_user: root
          ansible_ssh_pass: new_node_password
          # Optional: Override global settings for this node
          # ansible_port: 2222
          # k3s_version: v1.30.2+k3s1
```

### Step 3: Deploy to the New Node

You have several deployment options:

#### Option A: Deploy Only to the New Node (Recommended)

```bash
# Deploy to a specific new node
ansible-playbook playbooks/site.yml -i inventory.dev.local.yml --limit 192.168.1.30
```

#### Option B: Deploy to All Agent Nodes

```bash
# This will re-run on existing agents (safe due to idempotency)
ansible-playbook playbooks/site.yml -i inventory.dev.local.yml --limit agent
```

#### Option C: Deploy Multiple New Nodes

```bash
# If adding multiple nodes at once
ansible-playbook playbooks/site.yml -i inventory.dev.local.yml --limit "192.168.1.30,192.168.1.31"
```

### Step 4: Verify Node Addition

```bash
# Check if the node joined successfully
kubectl get nodes -o wide

# Check node status
kubectl describe node <node-name>

# Verify node is ready
kubectl wait --for=condition=Ready node/<node-name> --timeout=300s
```

## Adding Server (Control Plane) Nodes

**⚠️ Warning**: Adding server nodes to an existing cluster requires careful planning, especially for HA configurations.

### Important Considerations

1. **Odd Number Rule**: K3s with embedded etcd requires an odd number of server nodes (1, 3, 5, 7)
2. **Existing Single Server**: If you have a single server and want HA, you must add 2 servers at once to reach 3
3. **Data Consistency**: Ensure proper backup before modifying server topology

### For Single Server to HA Migration

If migrating from 1 server to 3 servers:

```yaml
k3s_cluster:
  children:
    server:
      hosts:
        # Existing server
        192.168.1.10:
          ansible_user: root
          ansible_ssh_pass: server1_password

        # New servers (add both at once)
        192.168.1.11:
          ansible_user: root
          ansible_ssh_pass: server2_password
        192.168.1.12:
          ansible_user: root
          ansible_ssh_pass: server3_password
```

Then run:

```bash
# Deploy to all servers
ansible-playbook playbooks/site.yml -i inventory.yml --limit server
```

## Verification

After adding any node, perform these verification steps:

### 1. Check Node Status

```bash
# List all nodes
kubectl get nodes

# Expected output:
# NAME            STATUS   ROLES                  AGE   VERSION
# server-node-1   Ready    control-plane,master   10d   v1.30.2+k3s1
# agent-node-1    Ready    <none>                 10d   v1.30.2+k3s1
# new-node        Ready    <none>                 5m    v1.30.2+k3s1
```

### 2. Check System Pods

```bash
# Ensure system pods are running on the new node
kubectl get pods -A -o wide | grep <new-node-name>
```

### 3. Test Workload Scheduling

```bash
# Create a test pod on the new node
kubectl run test-pod --image=nginx --overrides='{"spec":{"nodeName":"<new-node-name>"}}'

# Verify it's running
kubectl get pod test-pod

# Clean up
kubectl delete pod test-pod
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Node Stuck in NotReady State

```bash
# Check kubelet logs on the affected node
sudo journalctl -u k3s-agent -f

# Common causes:
# - Network connectivity issues
# - Wrong token or server URL
# - Time sync issues
```

#### 2. Authentication Failures

```bash
# Verify token on the server node
sudo cat /var/lib/rancher/k3s/server/node-token

# Ensure it matches the token in your inventory file
```

#### 3. Network Connectivity Issues

```bash
# From the new node, test connectivity to the server
curl -k https://<server-ip>:6443

# Check if required ports are open
sudo netstat -tlnp | grep -E '6443|10250|8472'
```

#### 4. DNS Resolution Issues

```bash
# Ensure nodes can resolve each other
ping <server-node-hostname>

# Add entries to /etc/hosts if needed
echo "192.168.1.10 server-node-1" | sudo tee -a /etc/hosts
```

### Debug Commands

```bash
# Get detailed node information
kubectl describe node <node-name>

# Check node conditions
kubectl get nodes -o json | jq '.items[].status.conditions'

# View agent logs
sudo journalctl -u k3s-agent --since "10 minutes ago"

# Check K3s agent status
sudo systemctl status k3s-agent
```

## Advanced Scenarios

### Adding Nodes with Custom Configuration

You can override per-node settings in the inventory:

```yaml
agent:
  hosts:
    192.168.1.30:
      ansible_user: ubuntu
      ansible_ssh_private_key_file: ~/.ssh/custom_key
      # Node-specific K3s configuration
      extra_agent_args: "--node-label=workload=gpu --node-taint=gpu=true:NoSchedule"
      # Different K3s version
      k3s_version: v1.29.0+k3s1
```

### Adding Nodes Behind NAT/Firewall

For nodes behind NAT or restrictive firewalls:

```yaml
agent:
  hosts:
    10.0.0.50:
      ansible_user: root
      ansible_ssh_pass: password
      # Use a jump host
      ansible_ssh_common_args: '-o ProxyCommand="ssh -W %h:%p jumphost"'
      # Specify external IP for node
      extra_agent_args: "--node-external-ip=203.0.113.10"
```

### Batch Node Addition

For adding many nodes efficiently:

1. Create a separate inventory file for new nodes:

```yaml
# new-nodes.yml
new_agents:
  hosts:
    192.168.1.30:
    192.168.1.31:
    192.168.1.32:
    192.168.1.33:
  vars:
    ansible_user: root
    ansible_ssh_pass: common_password
```

2. Run playbook with both inventories:

```bash
ansible-playbook playbooks/site.yml -i inventory.yml -i new-nodes.yml --limit new_agents
```

### Pre-staging K3s Binary (Airgap)

For environments with limited internet access:

```bash
# Download K3s binary on a machine with internet
wget https://github.com/k3s-io/k3s/releases/download/v1.30.2+k3s1/k3s

# Copy to the new node
scp k3s root@new-node:/usr/local/bin/
ssh root@new-node chmod +x /usr/local/bin/k3s

# Then run the playbook
ansible-playbook playbooks/site.yml -i inventory.yml --limit new-node
```

## Best Practices

1. **Always Backup**: Before modifying cluster topology, backup etcd data
2. **Test First**: Test the process in a development environment
3. **Monitor Resources**: Ensure new nodes have adequate CPU/Memory
4. **Version Consistency**: Keep all nodes on the same K3s version
5. **Document Changes**: Maintain an updated inventory and document any custom configurations

## Related Documentation

- [K3s Official Documentation](https://docs.k3s.io/)
- [Ansible Playbook Documentation](https://docs.ansible.com/ansible/latest/user_guide/playbooks.html)
- [Kubernetes Node Management](https://kubernetes.io/docs/concepts/architecture/nodes/)
