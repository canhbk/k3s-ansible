# Fix Unschedulable Node - vps15

## Problem

Node vps15 is marked as unschedulable by Longhorn due to disk pressure:

- Total disk: 95 GB
- Available: 22 GB (23%)
- Required minimum: 23 GB (25%)

## Solutions

### Option 1: Free Up Disk Space (Recommended)

Clean up unnecessary files and containers on vps15:

```bash
# SSH to the node
ssh vps15

# Clean up Docker/containerd
sudo crictl rmi --prune
sudo journalctl --vacuum-time=3d

# Check what's using space
df -h /var/lib/longhorn/
du -sh /var/lib/* | sort -h
```

### Option 2: Adjust Longhorn Storage Settings

Lower the minimum available percentage threshold:

```bash
# Edit Longhorn settings
kubectl -n longhorn-system edit settings.longhorn.io storage-minimal-available-percentage

# Change from 25 to 20 (or lower)
# This will allow nodes with 20% free space to be schedulable
```

### Option 3: Add More Storage

If possible, add additional storage to the node or expand the existing disk.

### Option 4: Exclude Node from Longhorn

If the node doesn't have enough storage for Longhorn:

```bash
# Add label to exclude from Longhorn
kubectl label node vps15 node.longhorn.io/create-default-disk=false --overwrite

# Or taint the node
kubectl taint nodes vps15 longhorn=no-storage:NoSchedule
```

## Verification

After applying fixes, check node status:

```bash
# Check Longhorn node status
kubectl -n longhorn-system get nodes.longhorn.io vps15

# Check if schedulable
kubectl -n longhorn-system get nodes.longhorn.io vps15 -o jsonpath='{.status.conditions[?(@.type=="Schedulable")].status}'
```
