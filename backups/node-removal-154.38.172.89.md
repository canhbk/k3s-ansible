# Node Removal: 154.38.172.89 (vps17)

## Date: 2025-08-09

### Summary

Successfully removed node 154.38.172.89 (vps17) from the dev K3s cluster.

### Process

1. Cordoned and drained the node
2. Backed up data from StatefulSets:
   - PostgreSQL databases (ma-31, ma-34, mur-762)
   - RabbitMQ definitions
3. Force deleted pending pods
4. Deleted PVCs to release PVs
5. Monitored pod recreation on other nodes
6. Restored data to new pods
7. Deleted node from Kubernetes
8. Updated inventory files

### Data Migration

- PostgreSQL pods migrated to: vps16-h2cloud-vn, vps17-h2cloud-vn
- RabbitMQ migrated to: vps16-h2cloud-vn
- Prometheus migrated to: vps17-h2cloud-vn
- All data successfully restored

### Backup Files Created

- ma-31-postgres-backup.sql
- ma-34-postgres-backup.sql
- mur-762-postgres-backup.sql
- rabbitmq-definitions.json

Note: These backup files should be stored securely and can be deleted after verifying system stability.
