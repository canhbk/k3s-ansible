# PostgreSQL HA - VN Cluster

This directory contains the PostgreSQL HA configurations for the VN (Vietnam) production cluster.

## Clusters

### 1. Standard PostgreSQL Cluster

- **Cluster Name**: postgresql-ha
- **Namespace**: postgres-db
- **PostgreSQL Version**: 17.5
- **Storage**: Longhorn (5Gi)
- **Instance Count**: 1 (can be scaled for HA)

### 2. PostgreSQL with pgvector Cluster

- **Cluster Name**: postgresql-pgvector
- **Namespace**: postgres-db
- **PostgreSQL Version**: 17 with pgvector 0.8.0
- **Storage**: Longhorn (4Gi)
- **Instance Count**: 1 (can be scaled for HA)
- **Special Features**: pgvector extension for AI/ML workloads

## Deployment

### Standard PostgreSQL Cluster

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

### PostgreSQL with pgvector Cluster

1. Update passwords in `secrets-pgvector.yaml`:

   ```bash
   # Generate secure passwords
   openssl rand -base64 32
   ```

2. Deploy using the provided script:

   ```bash
   ./deploy-pgvector.sh
   ```

   Or manually:

   ```bash
   kubectl apply -f secrets-pgvector.yaml
   kubectl apply -f cluster-pgvector.yaml
   # Optional: Deploy LoadBalancer for external access
   kubectl apply -f postgres-murror-ai-loadbalancer.yaml
   ```

## Users and Databases

### Standard PostgreSQL Cluster

#### Users

- **postgres**: Superuser (managed by operator)
- **dev**: Development user (owner of default database)
- **be**: Backend application user

#### Databases

- **default**: Main database (owner: dev)
- **murror**: Application database (owner: be)

### PostgreSQL with pgvector Cluster

#### Users

- **postgres**: Superuser (managed by operator)
- **dev**: Development user (owner of default database)
- **be**: Backend application user
- **ai**: AI team user for ML/vector operations

#### Databases

- **default**: Main database (owner: dev)
- **murror-ai**: AI/ML database with pgvector (owner: ai)
- **murror-be**: Backend application database (owner: be)

## Storage Configuration

The cluster uses Longhorn storage with node affinity to ensure pods are scheduled on nodes with the `longhorn=true` label.

## Monitoring

### Check cluster status

```bash
# All clusters
kubectl get cluster -n postgres-db

# Standard cluster
kubectl describe cluster postgresql-ha -n postgres-db

# pgvector cluster
kubectl describe cluster postgresql-pgvector -n postgres-db
```

### View pods

```bash
# All pods
kubectl get pods -n postgres-db

# Standard cluster pods
kubectl get pods -n postgres-db -l cnpg.io/cluster=postgresql-ha

# pgvector cluster pods
kubectl get pods -n postgres-db -l cnpg.io/cluster=postgresql-pgvector
```

### Verify pgvector extension

```bash
kubectl exec -it -n postgres-db postgresql-pgvector-1 -- psql -U postgres -d murror-ai -c 'CREATE EXTENSION IF NOT EXISTS vector;'
kubectl exec -it -n postgres-db postgresql-pgvector-1 -- psql -U postgres -d murror-ai -c '\dx'
```

## Services

### Internal Services

Both clusters provide internal ClusterIP services:

- `postgresql-ha-r`: Read-only endpoint for standard cluster
- `postgresql-ha-rw`: Read-write endpoint for standard cluster
- `postgresql-pgvector-r`: Read-only endpoint for pgvector cluster
- `postgresql-pgvector-rw`: Read-write endpoint for pgvector cluster

### External Access

The pgvector cluster can optionally expose a LoadBalancer service:

- **Service Name**: postgres-murror-ai-pgvector
- **Port**: 5432
- **Target**: Primary instance with pgvector

## Connection Details

### PostgreSQL with pgvector Cluster

- **External IPs**: 14.225.210.108, 14.225.210.165, 14.225.210.170
- **Port**: 5432
- **Databases**: 
  - murror-ai (owner: ai) - with pgvector extension
  - murror-be (owner: be)
- **Connection string example**:
  ```
  postgresql://ai:<password>@14.225.210.108:5432/murror-ai
  ```

## Backup and Recovery

CloudNative-PG supports various backup methods. Configure backup according to your requirements.
