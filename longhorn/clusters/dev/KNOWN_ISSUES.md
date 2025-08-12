# Dev Cluster - Known Issues

## Prerequisites Missing on Some Nodes

As of August 12, 2025, the following nodes in the dev cluster are missing required prerequisites for Longhorn:

### Affected Nodes

- **vps1**: Missing `open-iscsi`, `nfs-common`, `cryptsetup` packages
- **vps15**: Missing `open-iscsi`, `nfs-common`, `cryptsetup` packages
- **vps7**: Missing `open-iscsi`, `cryptsetup` packages

### Impact

- Longhorn manager pods on these nodes are in `CrashLoopBackOff` state
- Storage operations will not work on these nodes
- Longhorn will only use healthy nodes for volume provisioning

### Resolution

To fix this issue, install the missing packages on affected nodes:

```bash
# For Ubuntu/Debian nodes
sudo apt-get update
sudo apt-get install -y open-iscsi nfs-common cryptsetup

# Enable and start iscsid service
sudo systemctl enable iscsid
sudo systemctl start iscsid

# Load dm_crypt module
sudo modprobe dm_crypt
echo "dm_crypt" | sudo tee -a /etc/modules
```

After installing prerequisites, delete the failing pods to restart them:

```bash
kubectl -n longhorn-system delete pod -l app=longhorn-manager --field-selector spec.nodeName=vps1
kubectl -n longhorn-system delete pod -l app=longhorn-manager --field-selector spec.nodeName=vps15
kubectl -n longhorn-system delete pod -l app=longhorn-manager --field-selector spec.nodeName=vps7
```

## CoreDNS Replica Warning

- CoreDNS is running with fewer than 2 replicas
- This may impact DNS resolution reliability
- Consider scaling CoreDNS to at least 2 replicas for HA

## Multipathd Service

- Some nodes have `multipathd.service` running
- This can cause issues with Longhorn volumes
- See: <https://longhorn.io/kb/troubleshooting-volume-with-multipath/>
