# Dev SG3 Reader - Cluster-Wide Workload Read-Only Access

This directory contains RBAC configuration for providing developers with **cluster-wide read-only access** to basic workload resources in the sg3 production cluster.

**Created**: 2025-12-04
**Cluster**: sg3 (Production - Singapore)
**API Server**: https://15.235.211.39:6443

## Overview

The `dev-sg3-reader` ServiceAccount provides cluster-wide read-only access to basic Kubernetes workloads across all namespaces in the sg3 cluster. This is designed for developers who need to:

- View pods and their logs across all namespaces
- Debug applications using `kubectl exec`
- Monitor workload status (deployments, statefulsets, jobs)
- Troubleshoot issues in production

## Security Model

**Access Level**: Cluster-wide read-only (all namespaces)
**Principle**: Least privilege - only essential resources for debugging
**Restrictions**: No access to secrets, configmaps, networking, or storage resources

## Components

- **dev-sg3-reader-secret.yaml**: ServiceAccount and token secret in the `dev-access` namespace
- **cluster-workload-reader-role.yaml**: ClusterRole defining workload read permissions
- **cluster-role-binding.yaml**: ClusterRoleBinding connecting ServiceAccount to ClusterRole
- **generate-kubeconfig.sh**: Script to generate the kubeconfig file

## Permissions Granted

### Core Resources (API group: '')
- **Pods**: get, list, watch, logs, status
- **Pod Exec**: create (for debugging - `kubectl exec`)
- **Namespaces**: get, list, watch
- **Events**: get, list, watch

### Workload Resources (API group: apps)
- **Deployments**: get, list, watch
- **ReplicaSets**: get, list, watch
- **StatefulSets**: get, list, watch
- **DaemonSets**: get, list, watch

### Batch Resources (API group: batch)
- **Jobs**: get, list, watch
- **CronJobs**: get, list, watch

## What's NOT Included

For security reasons, the following are intentionally excluded:

- ConfigMaps and Secrets (sensitive data)
- Services and Ingresses (networking)
- PersistentVolumeClaims (storage)
- RBAC resources (roles, rolebindings)
- Custom Resource Definitions
- Cluster-level admin resources

## Setup Instructions

### Prerequisites

- Access to sg3 cluster with admin privileges
- kubectl configured with sg3 context

### Installation

1. **Switch to sg3 cluster context**:
   ```bash
   kubectl config use-context sg3
   ```

2. **Verify cluster connection**:
   ```bash
   kubectl cluster-info
   # Should show: https://15.235.211.39:6443
   ```

3. **Apply RBAC resources**:
   ```bash
   # Apply in order
   kubectl apply -f dev-sg3-reader-secret.yaml
   kubectl apply -f cluster-workload-reader-role.yaml
   kubectl apply -f cluster-role-binding.yaml
   ```

4. **Verify resources were created**:
   ```bash
   kubectl get namespace dev-access
   kubectl get sa -n dev-access dev-sg3-reader
   kubectl get secret -n dev-access dev-sg3-reader-secret
   kubectl get clusterrole cluster-workload-reader
   kubectl get clusterrolebinding dev-sg3-reader-binding
   ```

5. **Generate kubeconfig**:
   ```bash
   chmod +x generate-kubeconfig.sh
   ./generate-kubeconfig.sh
   ```

6. **Test the kubeconfig**:
   ```bash
   kubectl --kubeconfig=dev-sg3-reader.kubeconfig.yaml get namespaces
   kubectl --kubeconfig=dev-sg3-reader.kubeconfig.yaml get pods -A
   ```

## Usage for Developers

### Basic Commands

```bash
# List all namespaces
kubectl --kubeconfig=dev-sg3-reader.kubeconfig.yaml get ns

# List all pods across all namespaces
kubectl --kubeconfig=dev-sg3-reader.kubeconfig.yaml get pods -A

# List pods in specific namespace
kubectl --kubeconfig=dev-sg3-reader.kubeconfig.yaml get pods -n influxdb

# View pod logs
kubectl --kubeconfig=dev-sg3-reader.kubeconfig.yaml logs -n influxdb <pod-name>

# Follow logs
kubectl --kubeconfig=dev-sg3-reader.kubeconfig.yaml logs -f -n influxdb <pod-name>

# View logs from specific container
kubectl --kubeconfig=dev-sg3-reader.kubeconfig.yaml logs -n influxdb <pod-name> -c <container-name>
```

### Debugging Commands

```bash
# Execute command in pod
kubectl --kubeconfig=dev-sg3-reader.kubeconfig.yaml exec -n influxdb <pod-name> -- ls -la

# Interactive shell
kubectl --kubeconfig=dev-sg3-reader.kubeconfig.yaml exec -it -n influxdb <pod-name> -- /bin/sh

# Check environment variables
kubectl --kubeconfig=dev-sg3-reader.kubeconfig.yaml exec -n influxdb <pod-name> -- env

# View file contents
kubectl --kubeconfig=dev-sg3-reader.kubeconfig.yaml exec -n influxdb <pod-name> -- cat /app/config.json
```

### Workload Inspection

```bash
# List deployments
kubectl --kubeconfig=dev-sg3-reader.kubeconfig.yaml get deployments -A

# Describe deployment
kubectl --kubeconfig=dev-sg3-reader.kubeconfig.yaml describe deployment -n influxdb <deployment-name>

# List statefulsets
kubectl --kubeconfig=dev-sg3-reader.kubeconfig.yaml get statefulsets -A

# List jobs
kubectl --kubeconfig=dev-sg3-reader.kubeconfig.yaml get jobs -A

# View events
kubectl --kubeconfig=dev-sg3-reader.kubeconfig.yaml get events -A --sort-by='.lastTimestamp'
```

### Kubeconfig Management

**Option 1: Use --kubeconfig flag** (Recommended)
```bash
kubectl --kubeconfig=dev-sg3-reader.kubeconfig.yaml get pods -A
```

**Option 2: Export as environment variable**
```bash
export KUBECONFIG=/path/to/dev-sg3-reader.kubeconfig.yaml
kubectl get pods -A
```

**Option 3: Merge with existing kubeconfig**
```bash
KUBECONFIG=~/.kube/config:/path/to/dev-sg3-reader.kubeconfig.yaml \
  kubectl config view --flatten > ~/.kube/config.new
mv ~/.kube/config.new ~/.kube/config
kubectl config use-context dev-sg3-reader-context
```

## Security Notes

### Access Control
- **Read-only**: No create, update, or delete operations allowed
- **Cluster-wide**: Access to all namespaces (including system namespaces)
- **Limited resources**: Only basic workloads, pods, and events
- **No sensitive data**: Cannot access secrets, configmaps, or networking resources

### Token Security
- The kubeconfig contains a ServiceAccount token - treat it like a password
- **Never commit** kubeconfig files to version control (covered by .gitignore)
- Store securely using 1Password, HashiCorp Vault, or similar
- Rotate tokens regularly (recommended: quarterly for production)
- Tokens can be revoked by deleting the Secret

### Verification Commands

```bash
# Verify ServiceAccount permissions
kubectl auth can-i get pods --as=system:serviceaccount:dev-access:dev-sg3-reader -n influxdb
# Should return: yes

kubectl auth can-i create pods --as=system:serviceaccount:dev-access:dev-sg3-reader -n influxdb
# Should return: no

kubectl auth can-i get secrets --as=system:serviceaccount:dev-access:dev-sg3-reader -n influxdb
# Should return: no

kubectl auth can-i create pods/exec --as=system:serviceaccount:dev-access:dev-sg3-reader -n influxdb
# Should return: yes (for debugging)
```

## Troubleshooting

### Kubeconfig Generation Fails

**Error**: "Not on sg3 context"
```bash
kubectl config use-context sg3
```

**Error**: "Namespace 'dev-access' does not exist"
```bash
kubectl apply -f dev-sg3-reader-secret.yaml
```

**Error**: "ServiceAccount does not exist"
```bash
kubectl apply -f dev-sg3-reader-secret.yaml
```

**Error**: "Token is empty"
- Wait a few seconds for Kubernetes to populate the Secret
- Verify Secret exists: `kubectl get secret -n dev-access dev-sg3-reader-secret`
- Check Secret data: `kubectl get secret -n dev-access dev-sg3-reader-secret -o yaml`

### Access Denied Errors

**Error**: "pods is forbidden"

1. Verify ClusterRole exists:
   ```bash
   kubectl get clusterrole cluster-workload-reader
   ```

2. Verify ClusterRoleBinding exists:
   ```bash
   kubectl get clusterrolebinding dev-sg3-reader-binding
   ```

3. Check binding configuration:
   ```bash
   kubectl get clusterrolebinding dev-sg3-reader-binding -o yaml
   ```

4. Verify ServiceAccount:
   ```bash
   kubectl get sa -n dev-access dev-sg3-reader
   ```

### Token Expired or Invalid

If the token becomes invalid or needs rotation:

1. Delete the Secret:
   ```bash
   kubectl delete secret dev-sg3-reader-secret -n dev-access
   ```

2. Recreate the Secret:
   ```bash
   kubectl apply -f dev-sg3-reader-secret.yaml
   ```

3. Regenerate kubeconfig:
   ```bash
   ./generate-kubeconfig.sh
   ```

4. Distribute new kubeconfig to developers

## Maintenance

### Updating Permissions

To add or modify permissions:

1. Edit `cluster-workload-reader-role.yaml`
2. Apply changes:
   ```bash
   kubectl apply -f cluster-workload-reader-role.yaml
   ```
3. Existing kubeconfigs will automatically use updated permissions (no need to regenerate)

### Revoking Access

To completely remove access:

```bash
# Delete ClusterRoleBinding (revokes access immediately)
kubectl delete clusterrolebinding dev-sg3-reader-binding

# Delete ClusterRole
kubectl delete clusterrole cluster-workload-reader

# Delete ServiceAccount and Secret
kubectl delete -f dev-sg3-reader-secret.yaml
```

### Monitoring Usage

Check ServiceAccount token usage:
```bash
kubectl get secret -n dev-access dev-sg3-reader-secret -o jsonpath='{.metadata.creationTimestamp}'
```

Audit ServiceAccount activity (requires audit logging enabled):
```bash
kubectl get events -n dev-access --field-selector involvedObject.name=dev-sg3-reader
```

## Best Practices

1. **Distribute Securely**: Share kubeconfig via secure channels (1Password sharing, encrypted email)
2. **Rotate Regularly**: Rotate tokens quarterly for production environments
3. **Monitor Access**: Review audit logs periodically for unusual activity
4. **Document Recipients**: Maintain a list of who has access to this kubeconfig
5. **Revoke When Done**: Remove access when developers no longer need it
6. **Use Namespaced Access**: For specific project work, consider namespace-restricted access instead

## Related Documentation

- [Cluster RBAC Overview](../../README.md)
- [Dev Logger (similar pattern)](../../dev/dev-logger/README.md)
- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Project Security Guidelines](../../../../docs/SECURITY_GUIDELINES.md)

## Support

For issues or questions:
1. Check troubleshooting section above
2. Verify cluster connectivity: `kubectl config use-context sg3 && kubectl cluster-info`
3. Test with admin kubeconfig first to isolate RBAC vs cluster issues
4. Review Kubernetes audit logs if available

---

**Last Updated**: 2025-12-04
**Cluster**: sg3 (Production - Singapore)
**Pattern**: Cluster-wide read-only workload access
