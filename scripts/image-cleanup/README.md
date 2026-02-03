# Weekly Container Image Cleanup

Automated cleanup of unused container images on all K3s cluster nodes.

## Overview

This CronJob automatically removes unused (dangling) container images from all nodes in the cluster on a weekly schedule. It helps prevent disk space exhaustion caused by accumulated old images.

## How It Works

1. **CronJob** triggers every Sunday at 2:00 AM
2. **Controller Pod** discovers all nodes in the cluster
3. **Per-Node Jobs** are created dynamically for each node
4. Each job runs `crictl rmi --prune` on the host to remove unreferenced images
5. Jobs auto-cleanup after 1 hour (ttlSecondsAfterFinished)

## Architecture

```
CronJob (weekly @ 2:00 AM Sunday)
    └── Controller Pod (bitnami/kubectl)
            ├── Job: image-cleanup-node1-TIMESTAMP
            ├── Job: image-cleanup-node2-TIMESTAMP
            └── ... (one per node)
```

## Components

| Resource | Name | Purpose |
|----------|------|---------|
| ServiceAccount | `image-cleanup-sa` | Identity for controller pod |
| ClusterRole | `image-cleanup-role` | Permissions to list nodes, manage jobs |
| ClusterRoleBinding | `image-cleanup-binding` | Binds role to service account |
| CronJob | `weekly-image-cleanup` | Weekly scheduler |

## Safety Features

- **Safe pruning**: `crictl rmi --prune` only removes unreferenced images
- **No overlap**: `concurrencyPolicy: Forbid` prevents concurrent runs
- **Auto-cleanup**: Completed jobs are deleted after 1 hour
- **Resource limits**: Jobs have CPU/memory limits
- **Universal tolerations**: Runs on all nodes including control plane

## Deployment

### Deploy to a single cluster

```bash
kubectl config use-context <cluster-name>
kubectl apply -f weekly-image-cleanup-cronjob.yaml
```

### Deploy to all target clusters

```bash
for cluster in sg3 vn eu us; do
  echo "Deploying to $cluster..."
  kubectl config use-context $cluster
  kubectl apply -f weekly-image-cleanup-cronjob.yaml
done
```

## Verification

### Check CronJob status

```bash
kubectl get cronjob -n kube-system weekly-image-cleanup
```

### View scheduled runs

```bash
kubectl describe cronjob -n kube-system weekly-image-cleanup
```

### Manual test run

```bash
# Create a one-time job from the CronJob
kubectl create job --from=cronjob/weekly-image-cleanup manual-cleanup-$(date +%s) -n kube-system

# Watch the job progress
kubectl get jobs -n kube-system -l app=image-cleanup -w

# View controller logs
kubectl logs -n kube-system -l app=image-cleanup,component=controller -f

# View per-node cleanup logs
kubectl logs -n kube-system -l app=image-cleanup,component=node-cleanup
```

## Monitoring

### Check recent job history

```bash
kubectl get jobs -n kube-system -l app=image-cleanup --sort-by=.metadata.creationTimestamp
```

### View cleanup results for a specific node

```bash
kubectl logs -n kube-system -l app=image-cleanup,node=<node-name>
```

### Check for failed jobs

```bash
kubectl get jobs -n kube-system -l app=image-cleanup --field-selector status.successful=0
```

## Troubleshooting

### CronJob not running

1. Check CronJob status:
   ```bash
   kubectl describe cronjob -n kube-system weekly-image-cleanup
   ```

2. Verify schedule (uses cluster timezone):
   ```bash
   kubectl get cronjob -n kube-system weekly-image-cleanup -o jsonpath='{.spec.schedule}'
   ```

### Jobs failing

1. Check job status:
   ```bash
   kubectl describe job -n kube-system <job-name>
   ```

2. View pod logs:
   ```bash
   kubectl logs -n kube-system -l job-name=<job-name>
   ```

### Permission errors

Verify RBAC is correctly configured:
```bash
kubectl auth can-i list nodes --as=system:serviceaccount:kube-system:image-cleanup-sa
kubectl auth can-i create jobs --as=system:serviceaccount:kube-system:image-cleanup-sa -n kube-system
```

## Uninstall

```bash
kubectl delete -f weekly-image-cleanup-cronjob.yaml
```

Or selectively:
```bash
kubectl delete cronjob -n kube-system weekly-image-cleanup
kubectl delete clusterrolebinding image-cleanup-binding
kubectl delete clusterrole image-cleanup-role
kubectl delete serviceaccount -n kube-system image-cleanup-sa
```

## Customization

### Change schedule

Edit the CronJob schedule field:
```yaml
spec:
  schedule: "0 3 * * 1"  # Monday at 3:00 AM instead
```

### Add notifications

Add a sidecar or post-cleanup step to send notifications to Slack, email, etc.

### Exclude specific nodes

Modify the controller script to filter out specific nodes:
```bash
NODES=$(kubectl get nodes -l node-type!=special -o jsonpath='{.items[*].metadata.name}')
```
