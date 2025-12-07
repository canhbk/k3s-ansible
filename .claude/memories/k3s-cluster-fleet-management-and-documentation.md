# K3s Cluster Fleet Management and Documentation Practices

## Fleet Overview

The project manages **8 K3s clusters** across different environments and regions:

- **dev**: Development environment
- **eu**: Europe region
- **jp**: Japan region
- **sg**: Singapore region
- **sg2**: Singapore region (secondary)
- **us**: United States region
- **vn**: Vietnam region
- **vn2**: Vietnam region (secondary)

## Discovering and Understanding the Fleet

### Inventory Files

Each cluster has a corresponding inventory file:

```
inventory.dev.local.yml
inventory.eu.yml
inventory.jp.yml
inventory.sg.yml
inventory.sg2.yml
inventory.us.yml
inventory.vn.yml
inventory.vn2.yml
```

### Cluster Discovery Commands

```bash
# List all inventory files
ls inventory*.yml

# Check cluster status
kubectl config get-contexts
kubectl get nodes --context=<cluster-context>

# Verify cluster connectivity
ansible all -i inventory.<env>.yml -m ping
```

## Documentation Practices

### Documentation Location

- All cluster documentation is stored in the `docs/` directory
- Each cluster should have its own documentation section
- Keep environment-specific configurations documented

### Critical Documentation Rules

1. **Always Update Documentation When Making Changes**
   - Before deploying: Document planned changes
   - After deploying: Update with actual results
   - Include configuration changes, version updates, and infrastructure modifications

2. **Verify Current State Before Documenting**

   ```bash
   # Check current K3s version
   kubectl version --context=<cluster-context>

   # Verify node status
   kubectl get nodes -o wide --context=<cluster-context>

   # Check running applications
   kubectl get deployments,services --all-namespaces --context=<cluster-context>
   ```

3. **Documentation Accuracy Practices**
   - Use `kubectl` commands to verify information before documenting
   - Document actual deployed versions, not intended versions
   - Include timestamps for significant changes
   - Cross-reference inventory files with documentation
   - Validate connectivity and functionality after changes

### Maintenance Workflow

1. **Before Changes**: Check current state and document baseline
2. **During Changes**: Document steps and any deviations
3. **After Changes**: Verify deployment and update documentation
4. **Regular Reviews**: Periodically audit documentation against actual cluster state

This systematic approach ensures documentation remains accurate and useful for fleet management across all 8 clusters.
