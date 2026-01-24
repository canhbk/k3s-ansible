# Longhorn Volume Formatting Issue - SG3 Cluster

## Critical Infrastructure Bug Report

**Date**: 2025-11-25
**Cluster**: sg3 (8 nodes, Longhorn 1.9.1)
**Severity**: CRITICAL - Affects ALL new volume creation

## Executive Summary

All new persistent volume creation on the sg3 cluster is failing with a device formatting error. This is a **cluster-wide infrastructure issue**, not specific to RabbitMQ.

## Symptom

Pods requiring new persistent volumes are stuck in `Init:0/1` or `ContainerCreating` status indefinitely.

**Error Message**:
```
MountVolume.MountDevice failed for volume "pvc-xxx" : rpc error: code = Internal desc = format of disk "/dev/longhorn/pvc-xxx" failed: type:("ext4") target:("...") options:("defaults") errcode:(exit status 1) output:(mke2fs 1.47.0 (5-Feb-2023)
/dev/longhorn/pvc-xxx is apparently in use by the system; will not make a filesystem here!
```

## Impact

### Affected
- ❌ **ALL new PVC creation** after 12:24 (Nov 25, 2025)
- ❌ RabbitMQ deployment (multiple attempts)
- ❌ Simple test PVC with nginx pod
- ❌ Both `longhorn` (3-replica) and `longhorn-fast` (2-replica) storage classes

### Not Affected
- ✅ Existing volumes continue working (Redis, PostgreSQL, Prometheus, Grafana)
- ✅ PostgreSQL volumes created before 12:24
- ✅ Disk space is abundant (82-86% free on all nodes)

## Root Cause Analysis

### Timeline of Events

| Time | Event | Status |
|------|-------|--------|
| 12:14-12:24 | PostgreSQL PVCs created | ✅ Success |
| 12:17 | Longhorn CSI components restarted (provisioner, attacher, resizer) | ⚠️ Trigger Event |
| 12:29-12:40 | RabbitMQ PVCs fail | ❌ Failure |
| 14:37-14:39 | All CSI components manually restarted | 🔧 Attempted Fix |
| 14:40 | RabbitMQ PVC still fails | ❌ Fix didn't work |
| 14:42 | Test PVC (nginx) also fails | ❌ Confirms cluster-wide issue |

### Root Cause

The Longhorn CSI driver's `mke2fs` utility reports that block devices are "apparently in use by the system" even though they are brand new volumes.

**Technical Details**:
- Block devices are successfully created at `/dev/longhorn/pvc-xxx`
- Longhorn successfully attaches volumes to nodes
- Device formatting with `mke2fs -F -m0 /dev/longhorn/pvc-xxx` fails
- Error suggests device has exclusive lock or stale device mapper reference

### What We've Tried

1. ✅ Restarted CSI provisioner deployment → No change
2. ✅ Restarted CSI attacher deployment → No change
3. ✅ Restarted CSI resizer deployment → No change
4. ✅ Deleted and recreated all CSI plugin DaemonSet pods → No change
5. ✅ Tried different storage classes (longhorn, longhorn-fast) → No change
6. ✅ Tried different nodes (vps53, vps55) → No change
7. ✅ Created simple test PVC (nginx) → Same failure

## Confirmed Facts

1. **Disk space is NOT the issue**: All nodes have 82-86% free space (verified via Longhorn UI screenshot)
2. **Storage class configuration is correct**: PostgreSQL uses the same `longhorn` storage class and works
3. **The issue started after CSI component restart at 12:17**
4. **Existing volumes are unaffected**: All services using pre-existing volumes continue operating normally
5. **This is NOT workload-specific**: Affects RabbitMQ, test nginx pod, and any new volume request

## Current State

### RabbitMQ Deployment
- **Configuration files**: ✅ Created and ready (`values.yaml`, `README.md`, `test-connection.yaml`)
- **Helm release**: ✅ Successfully deployed (status: deployed)
- **StatefulSet**: ✅ Created
- **Services**: ✅ Created (LoadBalancer with external IPs)
- **Ingress**: ✅ Created
- **PVC**: ✅ Bound to Longhorn volume
- **Pod status**: ❌ Stuck in `Init:0/1` - cannot mount volume

### Longhorn System
- **Version**: 1.9.1
- **CSI Components**: All Running with fresh restarts
- **Manager Pods**: 8/8 Running (one per node)
- **Storage Classes**: 5 configured (longhorn, longhorn-retain, longhorn-fast, longhorn-single, longhorn-static)
- **Existing Volumes**: All healthy and operational

## Recommended Next Steps

### Immediate Actions

1. **Escalate to Longhorn/Infrastructure Team**
   - This is beyond application-level troubleshooting
   - Requires node-level or Longhorn manager investigation
   - May need Longhorn upgrade or patch

2. **Investigate Kubernetes/Node Level**
   ```bash
   # SSH to affected node
   ssh -i ~/.ssh/canhnv_vps ubuntu@15.235.197.207  # vps55

   # Check device mapper
   sudo dmsetup ls
   sudo dmsetup status

   # Check if devices have holders
   ls -la /sys/block/ | grep longhorn

   # Check for stale mounts
   sudo mount | grep longhorn

   # Check kubelet logs
   sudo journalctl -u k3s-agent -n 100 | grep longhorn
   ```

3. **Check Longhorn Manager Logs in Detail**
   ```bash
   kubectl logs -n longhorn-system -l app=longhorn-manager --tail=500 > longhorn-manager-logs.txt
   # Search for device mapper or formatting errors
   ```

4. **Consider Longhorn Upgrade**
   - Current version: 1.9.1
   - Check if this is a known issue in Longhorn GitHub issues
   - Consider upgrading to 1.9.2 or 1.10.x if fix is available

### Workarounds (if immediate fix not possible)

1. **Use Existing Volumes**
   - Clone/snapshot existing working volumes
   - Restore from Longhorn snapshots

2. **Use HostPath or Local-Path**
   - Temporary workaround for non-critical data
   - Not recommended for production

3. **Deploy to Different Cluster**
   - Deploy RabbitMQ to VN, US, or EU cluster temporarily
   - Migrate workloads away from sg3 until fixed

## Technical Investigation Commands

### Check Device Mapper State
```bash
# On affected node (vps55)
kubectl exec -n longhorn-system longhorn-csi-plugin-<pod> -c longhorn-csi-plugin -- dmsetup ls
kubectl exec -n longhorn-system longhorn-csi-plugin-<pod> -c longhorn-csi-plugin -- lsblk
```

### Check for File Locks
```bash
# List open files on Longhorn devices
kubectl exec -n longhorn-system longhorn-csi-plugin-<pod> -c longhorn-csi-plugin -- lsof | grep longhorn
```

### Force Wipe Device (DANGEROUS - only if approved)
```bash
# SSH to node
ssh -i ~/.ssh/canhnv_vps ubuntu@<node-ip>

# Wipe filesystem signatures
sudo wipefs -a /dev/longhorn/pvc-xxx

# Or force format
sudo mkfs.ext4 -F /dev/longhorn/pvc-xxx
```

## References

- Longhorn Version: 1.9.1
- K3s Version: v1.32.5+k3s1
- Kernel: Ubuntu 24.04.3 LTS
- Longhorn GitHub Issues: https://github.com/longhorn/longhorn/issues
- Related Issue: https://github.com/longhorn/longhorn/issues/3552 (device in use)

## Contact Information

**Cluster**: sg3 (Singapore OVH)
**Kubeconfig**: `/Users/canhnv/development/canhnv/k3s-ansible/kubeconfig-sg3`
**Context**: `sg3`
**Longhorn UI**: https://sg3.longhorn.canhnv.com

## Files Created for RabbitMQ (Ready when Longhorn is fixed)

1. `/Users/canhnv/development/canhnv/k3s-ansible/rabbitmq/clusters/sg3/values.yaml`
2. `/Users/canhnv/development/canhnv/k3s-ansible/rabbitmq/clusters/sg3/README.md`
3. `/Users/canhnv/development/canhnv/k3s-ansible/rabbitmq/clusters/sg3/test-connection.yaml`

Once Longhorn is fixed, deployment can proceed immediately using:
```bash
helm install rabbitmq bitnami/rabbitmq --version 15.5.3 --namespace rabbitmq --values values.yaml
```
