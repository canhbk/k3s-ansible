# Essential Commands for K3s Ansible Project

## Kubernetes Cluster Management

### Context Switching
```bash
# List all available clusters
kubectl config get-contexts

# Switch to specific cluster
kubectl config use-context dev        # Development
kubectl config use-context eu         # EU Production
kubectl config use-context vn         # Vietnam Primary
kubectl config use-context vn2        # Vietnam Secondary
# ... etc for jp, sg, sg2, us

# Verify current context
kubectl config current-context
```

### Node and Cluster Operations
```bash
# Check cluster health
kubectl get nodes -o wide
kubectl cluster-info
kubectl get all -A

# Monitor resource usage
kubectl top nodes
kubectl top pods -A
```

## Ansible Deployment Commands

### Cluster Deployment
```bash
# Deploy new K3s cluster
ansible-playbook playbooks/site.yml -i inventory.dev.local.yml
ansible-playbook playbooks/site.yml -i inventory.prod.yml
ansible-playbook playbooks/site.yml -i inventory.vn.yml

# Upgrade K3s version (update k3s_version in inventory first)
ansible-playbook playbooks/upgrade.yml -i inventory.yml

# Reboot cluster nodes safely
ansible-playbook playbooks/reboot.yml -i inventory.yml

# Reset/destroy cluster (DESTRUCTIVE)
ansible-playbook playbooks/reset.yml -i inventory.yml
```

### Development and Testing
```bash
# Install Ansible dependencies
ansible-galaxy collection install -r collections/requirements.yml

# Verbose execution for debugging
ansible-playbook playbooks/site.yml -i inventory.yml -vvv

# Target specific hosts
ansible-playbook playbooks/site.yml -i inventory.yml --limit server
ansible-playbook playbooks/site.yml -i inventory.yml --limit agent
```

## Development Workflow Commands

### Node Management
```bash
# Safely drain node before maintenance
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Make node schedulable again
kubectl uncordon <node-name>

# Remove node from cluster
kubectl delete node <node-name>
```

### Application Debugging
```bash
# Pod logs and debugging
kubectl logs -n <namespace> <pod-name> -f
kubectl describe pod -n <namespace> <pod-name>
kubectl exec -it -n <namespace> <pod-name> -- /bin/bash

# Check events and troubleshooting
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
kubectl get pv,pvc -A
```

## System Commands (macOS Darwin)

### Basic File Operations
```bash
# List files and directories
ls -la
find . -name "*.yml" -type f

# Search in files
grep -r "search-term" .
rg "search-term" .  # ripgrep (faster alternative)
```

### Git Operations
```bash
# Follow conventional commit format (Angular style)
git commit -m "feat(cluster): add node removal procedure"
git commit -m "fix(inventory): update dev cluster configuration"
git commit -m "docs(readme): update cluster overview"

# Check status and changes
git status
git diff
```

## Health Check Scripts

### Multi-Cluster Health Check
```bash
# Quick health check across all clusters
for context in dev eu jp sg sg2 us vn vn2; do
  echo "Checking cluster: $context"
  kubectl config use-context $context
  kubectl get nodes --no-headers | wc -l | xargs echo "Nodes:"
  echo "---"
done
```

### Storage and Services Check
```bash
# Check storage classes and volumes
kubectl get storageclass
kubectl get pv,pvc -A

# Check critical services
kubectl get svc -A | grep LoadBalancer
kubectl get ingress -A
```