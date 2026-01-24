# Distributed PostgreSQL Setup - Implementation Plan

## Overview

This plan implements distributed PostgreSQL using CloudNativePG with:

- Primary: cluster-pgvector in VN cluster
- Replica: cluster-pgvector-replica in US cluster
- WAL Storage: MinIO in US cluster (high performance)
- Replication: Combined streaming + WAL archiving

## Architecture

```
VN Cluster (Primary)                    US Cluster (High Performance)
┌─────────────────────┐                ┌─────────────────────┐
│ PostgreSQL Primary  │◄──────────────►│ PostgreSQL Replica  │
│ cluster-pgvector    │   Streaming    │ cluster-pgvector-   │
│                     │   Replication  │ replica             │
└──────────┬──────────┘                └──────────┬──────────┘
           │                                       │
           │ Write WAL                    Read WAL │ (local)
           │ (network)                             │
           └───────────────────────────────────────►
                                       ┌─────────────────────┐
                                       │   MinIO (US Only)   │
                                       │  WAL Archive Store  │
                                       │  External Access    │
                                       └─────────────────────┘
```

## Safety Requirements

⚠️ **CRITICAL**: Any operation that modifies the primary database in VN requires explicit confirmation
⚠️ **IMPORTANT**: Backup current configurations before any changes

## Implementation Phases

### Phase 1: MinIO Deployment in US Cluster [SAFE]

- No impact on existing databases
- Deploy MinIO with external access
- Configure security and TLS

### Phase 2: VN Primary Configuration [REQUIRES CONFIRMATION]

- ⚠️ Modifies existing cluster-pgvector
- Adds WAL archiving configuration
- Enables replication user
- Creates external service

### Phase 3: US Replica Deployment [SAFE]

- New deployment, no impact on primary
- Configures read-only replica
- Bootstrap from WAL archive

### Phase 4: Validation [SAFE]

- Read-only operations
- Monitoring setup
- Documentation

## Detailed Steps

### Step 1: Deploy MinIO in US Cluster

1. Create namespace `minio-system`
2. Deploy MinIO with 100Gi storage
3. Configure LoadBalancer service
4. Set up TLS certificates
5. Create buckets and access policies

### Step 2: Prepare VN Primary [REQUIRES CONFIRMATION]

1. Create backup of current configuration
2. Add barmanObjectStore configuration
3. Configure replication slots
4. Create replication user
5. Apply changes with zero downtime

### Step 3: Deploy US Replica

1. Create namespace and secrets
2. Deploy replica cluster
3. Monitor bootstrap progress
4. Validate replication

### Step 4: Testing & Validation

1. Verify WAL archiving
2. Check replication lag
3. Test read queries on replica
4. Document failover procedure

## Risk Mitigation

- All primary database changes are additive (no data loss risk)
- Replication user has minimal privileges
- WAL archiving runs async (no performance impact)
- Rollback procedures documented for each step

## Rollback Procedures

- Phase 1: Delete MinIO deployment
- Phase 2: Remove WAL archiving config from primary
- Phase 3: Delete replica deployment
- Phase 4: N/A (monitoring only)
