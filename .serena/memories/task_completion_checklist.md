# Task Completion Checklist

## Pre-Task Requirements
- Run lint and format checks before making commits
- Check syntax errors in YAML files
- Verify inventory configurations

## Code Quality Checks
```bash
# YAML linting (if yamllint is available)
yamllint playbooks/ roles/ inventory*.yml

# Ansible linting (if ansible-lint is available)  
ansible-lint playbooks/

# Syntax check for playbooks
ansible-playbook playbooks/site.yml -i inventory.yml --syntax-check
```

## Testing Commands
```bash
# Test connectivity to hosts
ansible all -i inventory.yml -m ping

# Dry-run deployment
ansible-playbook playbooks/site.yml -i inventory.yml --check

# Validate Kubernetes manifests
kubectl apply --dry-run=client -f manifest.yaml
```

## Documentation Updates
- [ ] Update relevant documentation in `docs/` directory
- [ ] Include actual commands used in examples
- [ ] Update service-specific docs if applicable
- [ ] Update cluster-specific docs if changes affect specific clusters
- [ ] Verify documentation matches actual cluster state

## Verification Steps
```bash
# Verify cluster connectivity
kubectl config get-contexts
kubectl get nodes

# Check service status
kubectl get all -A
kubectl get pv,pvc -A

# Verify specific changes
kubectl describe <resource-type> <resource-name>
```

## Git Operations
```bash
# Stage only relevant files (NOT git add .)
git add specific-file.yml
git add docs/updated-file.md

# Commit with conventional format
git commit -m "type(scope): description"

# Push changes
git push origin branch-name
```

## Safety Checks for Production
- [ ] Test changes in development environment first
- [ ] Verify current cluster context before applying changes
- [ ] Create backups for stateful workloads if needed
- [ ] Plan rollback procedure
- [ ] Monitor cluster health after changes