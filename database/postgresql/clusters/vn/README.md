# PostgreSQL HA - VN Cluster

This directory contains the PostgreSQL HA configuration for the VN (Vietnam) production cluster.

## Overview

- **Cluster Name**: postgresql-ha
- **Namespace**: postgres-db
- **PostgreSQL Version**: 17.5
- **Storage**: Longhorn (5Gi)
- **Instance Count**: 1 (can be scaled for HA)

## Deployment

1. Ensure CloudNative-PG operator is installed:

   ```bash
   kubectl get deploy -n cnpg-system cnpg-controller-manager
   ```

2. Create namespace:

   ```bash
   kubectl create namespace postgres-db
   ```

3. Apply secrets:

   ```bash
   kubectl apply -f secrets.yaml
   ```

4. Deploy cluster:

   ```bash
   kubectl apply -f cluster.yaml
   ```

## Users and Databases

### Users

- **postgres**: Superuser (managed by operator)
- **dev**: Development user (owner of default database)
- **be**: Backend application user

### Databases

- **default**: Main database (owner: dev)
- **murror**: Application database (owner: be)

## Storage Configuration

The cluster uses Longhorn storage with node affinity to ensure pods are scheduled on nodes with the `longhorn=true` label.

## Monitoring

Check cluster status:

```bash
kubectl get cluster -n postgres-db
kubectl describe cluster postgresql-ha -n postgres-db
```

View pods:

```bash
kubectl get pods -n postgres-db
```

## Backup and Recovery

CloudNative-PG supports various backup methods. Configure backup according to your requirements.
