# PostgreSQL HA - Dev Cluster

This directory contains the PostgreSQL HA configuration for the development cluster.

## Overview

- **Cluster Name**: postgresql-ha
- **Namespace**: postgres-db
- **PostgreSQL Version**: 17 with pgvector 0.8.0
- **Storage**: local-path (10Gi)
- **Instance Count**: 1

## Features

- pgvector extension for AI/ML workloads
- Multiple database users for different teams
- External LoadBalancer for AI team access

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

5. (Optional) Deploy LoadBalancer for external access:

   ```bash
   # For AI team access to murror-ai database
   kubectl apply -f postgres-murror-ai-loadbalancer.yaml

   # For testing access to murror-be database
   kubectl apply -f postgres-murror-be-loadbalancer.yaml
   ```

## Users and Databases

### Users

- **postgres**: Superuser (managed by operator)
- **dev**: Development user (owner of default database)
- **ai**: AI team user
- **be**: Backend application user
- **tester**: Read-only testing user (for murror-be database)

### Databases

- **default**: Main database (owner: dev)
- **murror-ai**: AI team database (owner: ai)
- **murror-be**: Backend database (owner: be)

## External Access

### AI Team Access
The `postgres-murror-ai-loadbalancer.yaml` creates a LoadBalancer service for AI team access:

- **Service**: postgres-murror-ai
- **Port**: 5432
- **Database**: murror-ai
- **User**: ai
- **Access**: Open to internet (DEVELOPMENT ONLY)

### Testing Access
The `postgres-murror-be-loadbalancer.yaml` creates a LoadBalancer service for testing access:

- **Service**: postgres-murror-be
- **Port**: 5432
- **Database**: murror-be
- **User**: tester (read-only)
- **Access**: Open to internet (DEVELOPMENT ONLY)

⚠️ **WARNING**: These LoadBalancers are open to the internet. Use only in development environments.

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

Check LoadBalancer IPs:

```bash
# AI team LoadBalancer
kubectl get svc postgres-murror-ai -n postgres-db

# Testing LoadBalancer
kubectl get svc postgres-murror-be -n postgres-db
```

## pgvector Extension

This cluster includes pgvector extension for vector similarity search, useful for:

- AI/ML applications
- Semantic search
- Recommendation systems

To use pgvector in a database:

```sql
CREATE EXTENSION vector;
```
