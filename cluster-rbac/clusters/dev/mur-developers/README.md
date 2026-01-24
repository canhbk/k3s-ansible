# Dev Cluster RBAC - Developers Read-Only Access

This directory contains RBAC configuration for providing developers with **namespace-restricted** read-only access to specific namespaces on the dev cluster.

**Updated**: 2025-11-04 (Post vps7 node removal - Changed from cluster-wide to namespace-restricted access)

## Overview

Developers are granted read-only access to the following namespaces for debugging and monitoring purposes:

### Target Namespaces
- **mu-* namespaces**: mu-43, mu-66, mu-69, mu-70, mu-81 (JIRA ticket pattern)
- **Alpha environments**: nsp-alpha-murror, nsp-alpha-murror-ai

This configuration uses **namespace-scoped Roles** instead of ClusterRoles to implement the principle of least privilege.

## Architecture

This setup uses **namespace-specific RBAC** for enhanced security:
- One ServiceAccount in `dev-access` namespace
- One Role per target namespace (not ClusterRole) for resource access
- One RoleBinding per target namespace (not ClusterRoleBinding) for resource access
- One ClusterRole for namespace listing (discoverability)
- One ClusterRoleBinding for namespace listing
- Access is explicitly granted only to listed namespaces

## Components

### Active Configuration Files
- **mur-developers-secret.yaml**: ServiceAccount and token secret in the `dev-access` namespace
- **dev-namespaces-reader-role.yaml**: Namespace-scoped Role defining read-only permissions
- **dev-namespaces-reader-rolebindings.yaml**: RoleBindings for each target namespace
- **namespace-lister-clusterrole.yaml**: ClusterRole for listing namespaces (discoverability)
- **namespace-lister-clusterrolebinding.yaml**: ClusterRoleBinding for namespace listing
- **generate-mur-kubeconfig.sh**: Script to generate the kubeconfig file

### Archived Files (Old Cluster-Wide Approach)
- **mur-namespaces-reader-role.yaml.old**: Previous ClusterRole (deprecated)
- **mur-developers-rolebinding.yaml.old**: Previous ClusterRoleBinding (deprecated)
- **mur-developers.kubeconfig.yaml.old**: Previous kubeconfig (deprecated)

## Permissions Granted

The following read-only permissions are granted:

### Core Resources
- ConfigMaps, Endpoints, Events
- Pods (including logs and status)
- **Pod Exec**: Execute commands inside containers for debugging and data inspection
- Services, PersistentVolumeClaims
- ReplicationControllers, ResourceQuotas

### Application Resources
- Deployments, ReplicaSets, StatefulSets, DaemonSets
- Jobs, CronJobs
- HorizontalPodAutoscalers

### Networking
- Ingresses, NetworkPolicies

### Cluster-Level Permissions
- **Namespaces**: List and get namespace information (for discoverability)
  - Note: This allows seeing ALL namespaces in the cluster, but does NOT grant access to resources within them

## Setup Instructions

### Initial Setup

1. Switch to dev cluster context:
```bash
kubectl config use-context dev
```

2. Create the dev-access namespace (if not exists):
```bash
kubectl create namespace dev-access
```

3. Apply the ServiceAccount and Secret:
```bash
kubectl apply -f mur-developers-secret.yaml
```

4. Apply the Role to each target namespace:
```bash
for ns in mu-43 mu-66 mu-69 mu-70 mu-81 nsp-alpha-murror nsp-alpha-murror-ai; do
  kubectl apply -f dev-namespaces-reader-role.yaml -n "$ns"
done
```

5. Apply all RoleBindings:
```bash
kubectl apply -f dev-namespaces-reader-rolebindings.yaml
```

6. Apply namespace listing permissions (for discoverability):
```bash
kubectl apply -f namespace-lister-clusterrole.yaml
kubectl apply -f namespace-lister-clusterrolebinding.yaml
```

7. Generate the kubeconfig:
```bash
chmod +x generate-mur-kubeconfig.sh
./generate-mur-kubeconfig.sh
```

8. Distribute the generated `mur-developers.kubeconfig.yaml` to developers.

### Adding New Namespaces

To grant access to a new namespace (e.g., `mu-100`):

1. Apply the Role to the new namespace:
```bash
kubectl apply -f dev-namespaces-reader-role.yaml -n mu-100
```

2. Add a new RoleBinding section to `dev-namespaces-reader-rolebindings.yaml`:
```yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dev-namespaces-reader-binding
  namespace: mu-100
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: dev-namespaces-reader
subjects:
  - kind: ServiceAccount
    name: mur-developers
    namespace: dev-access
```

3. Apply the updated RoleBindings:
```bash
kubectl apply -f dev-namespaces-reader-rolebindings.yaml
```

4. Update the README to list the new namespace.

5. Optionally regenerate kubeconfig (existing tokens will still work with new namespaces).

## Usage for Developers

Developers can use the kubeconfig in several ways:

### Option 1: Export as environment variable
```bash
export KUBECONFIG=/path/to/mur-developers.kubeconfig.yaml
kubectl get pods -n mur-604
```

### Option 2: Use --kubeconfig flag
```bash
kubectl --kubeconfig=mur-developers.kubeconfig.yaml get pods -n mur-604
```

### Option 3: Merge with existing kubeconfig
```bash
KUBECONFIG=~/.kube/config:/path/to/mur-developers.kubeconfig.yaml kubectl config view --flatten > ~/.kube/config.new
mv ~/.kube/config.new ~/.kube/config
kubectl config use-context mur-developers-context
```

## Example Commands

```bash
# List all namespaces (discover which ones exist)
kubectl --kubeconfig=mur-developers.kubeconfig.yaml get ns
# Note: Shows ALL namespaces, but you can only access resources in: mu-*, nsp-alpha-murror*

# List all pods in mu-43 namespace
kubectl --kubeconfig=mur-developers.kubeconfig.yaml get pods -n mu-43

# View logs for a specific pod
kubectl --kubeconfig=mur-developers.kubeconfig.yaml logs -n nsp-alpha-murror pod-name

# Execute commands inside a pod (for debugging or data inspection)
kubectl --kubeconfig=mur-developers.kubeconfig.yaml exec pod-name -n mu-81 -- cat /app/config.json
kubectl --kubeconfig=mur-developers.kubeconfig.yaml exec pod-name -n mu-81 -- env
kubectl --kubeconfig=mur-developers.kubeconfig.yaml exec -it pod-name -n mu-81 -- /bin/sh

# Access PostgreSQL database inside a pod
kubectl --kubeconfig=mur-developers.kubeconfig.yaml exec postgres-pod-name -n mu-81 -- psql -U postgres -c "SELECT version();"

# Get detailed information about a deployment
kubectl --kubeconfig=mur-developers.kubeconfig.yaml describe deployment -n mu-66 deployment-name

# List all services in nsp-alpha-murror-ai
kubectl --kubeconfig=mur-developers.kubeconfig.yaml get svc -n nsp-alpha-murror-ai

# Find accessible namespaces
kubectl --kubeconfig=mur-developers.kubeconfig.yaml get ns -o name | grep -E '(mu-|nsp-alpha-murror)'

# Test access (should work for permitted namespaces)
kubectl --kubeconfig=mur-developers.kubeconfig.yaml get pods -n mu-43

# Test access (should be denied for other namespaces)
kubectl --kubeconfig=mur-developers.kubeconfig.yaml get pods -n default
# Expected: Error from server (Forbidden): pods is forbidden...
```

## Security Notes

### Access Control
- This configuration provides **read-only** access - no create, update, or delete operations are allowed
- Access is **namespace-restricted** - only the explicitly listed namespaces are accessible
- Other namespaces (default, kube-system, etc.) are completely inaccessible
- Uses namespace-scoped Roles instead of ClusterRoles for enhanced security

### Token Security
- The kubeconfig contains a ServiceAccount token that should be kept secure
- Never commit kubeconfig files to version control
- Tokens can be revoked by deleting the Secret: `kubectl delete secret mur-developers-token -n dev-access`
- To regenerate: Delete and recreate the Secret, then run `generate-mur-kubeconfig.sh` again

### Verification
Verify access restrictions:
```bash
# Should succeed - read pods
kubectl auth can-i get pods --as=system:serviceaccount:dev-access:mur-developers -n mu-43

# Should succeed - execute commands in pods
kubectl auth can-i create pods/exec --subresource=exec --as=system:serviceaccount:dev-access:mur-developers -n mu-43

# Should fail - no access to other namespaces
kubectl auth can-i get pods --as=system:serviceaccount:dev-access:mur-developers -n default

# Should fail - no write permissions
kubectl auth can-i delete pods --as=system:serviceaccount:dev-access:mur-developers -n mu-43
```

## Troubleshooting

### Kubeconfig Generation Fails

If the kubeconfig generation fails:
1. Ensure you're connected to the dev cluster: `kubectl config current-context`
2. Verify the `dev-access` namespace exists: `kubectl get namespace dev-access`
3. Check that all RBAC resources were created successfully:
   ```bash
   kubectl get serviceaccount -n dev-access mur-developers
   kubectl get secret -n dev-access mur-developers-token
   kubectl get role -n mu-43 dev-namespaces-reader
   kubectl get rolebinding -n mu-43 dev-namespaces-reader-binding
   ```

### Access Denied Errors

If developers report access denied errors:

1. Verify RoleBindings exist in the target namespace:
   ```bash
   kubectl get rolebinding -n <namespace> dev-namespaces-reader-binding
   ```

2. Check if the Role exists in that namespace:
   ```bash
   kubectl get role -n <namespace> dev-namespaces-reader
   ```

3. Verify the ServiceAccount token is valid:
   ```bash
   kubectl get secret -n dev-access mur-developers-token -o jsonpath='{.data.token}' | base64 -d | wc -c
   # Should output a number > 0
   ```

4. Test access as the ServiceAccount:
   ```bash
   kubectl auth can-i get pods --as=system:serviceaccount:dev-access:mur-developers -n <namespace>
   ```

### Token Expired or Invalid

If the token becomes invalid:
1. Delete and recreate the Secret:
   ```bash
   kubectl delete secret mur-developers-token -n dev-access
   kubectl apply -f mur-developers-secret.yaml
   ```
2. Regenerate the kubeconfig:
   ```bash
   ./generate-mur-kubeconfig.sh
   ```
3. Distribute the new kubeconfig to developers.

## Maintenance

### Updating Permissions

To update permissions (e.g., add new resource types):
1. Edit the `dev-namespaces-reader-role.yaml` file
2. Apply to all target namespaces:
   ```bash
   for ns in mu-43 mu-66 mu-69 mu-70 mu-81 nsp-alpha-murror nsp-alpha-murror-ai; do
     kubectl apply -f dev-namespaces-reader-role.yaml -n "$ns"
   done
   ```
3. Existing kubeconfigs will automatically use the updated permissions (no need to regenerate)

### Removing Access from a Namespace

To revoke access from a specific namespace (e.g., `mu-43`):
```bash
kubectl delete rolebinding dev-namespaces-reader-binding -n mu-43
kubectl delete role dev-namespaces-reader -n mu-43
```

### Complete Cleanup

To remove all developer access:
```bash
# Delete all RoleBindings
for ns in mu-43 mu-66 mu-69 mu-70 mu-81 nsp-alpha-murror nsp-alpha-murror-ai; do
  kubectl delete rolebinding dev-namespaces-reader-binding -n "$ns"
  kubectl delete role dev-namespaces-reader -n "$ns"
done

# Delete ServiceAccount and Secret
kubectl delete -f mur-developers-secret.yaml
```

## Change Log

### 2025-11-04 (Update 2)
- **Enhancement**: Added `pods/exec` permission to enable command execution inside containers
- Developers can now run debugging commands and access data inside pods (e.g., `kubectl exec`, interactive shells)
- Updated documentation with pod exec examples (database access, file inspection, environment variables)
- Added verification commands for testing pod exec permissions
- All existing kubeconfigs automatically gain new permissions (no regeneration required)

### 2025-11-04 (Update 1)
- **Breaking Change**: Migrated from cluster-wide ClusterRole to namespace-scoped Roles
- Updated after vps7 node removal from dev cluster
- Added namespace-specific RoleBindings for: mu-43, mu-66, mu-69, mu-70, mu-81, nsp-alpha-murror, nsp-alpha-murror-ai
- Enhanced security by implementing explicit namespace restrictions
- Updated generate script with access verification
- Archived old cluster-wide configuration files