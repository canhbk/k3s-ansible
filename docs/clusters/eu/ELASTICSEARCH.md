# Elasticsearch on EU Cluster

## Overview

Elasticsearch is deployed on the EU cluster using Elastic Cloud on Kubernetes (ECK) operator. This provides a production-ready Elasticsearch cluster with automated management, monitoring, and integration with the existing Prometheus/Grafana stack.

**Last Updated**: 2026-01-25

## Architecture

### Components

- **ECK Operator**: Manages Elasticsearch lifecycle (v2.16.1)
- **Elasticsearch Cluster**: Single-node deployment (v8.17.0)
- **Kibana**: Web UI for Elasticsearch (v8.17.0)
- **Prometheus Exporter**: Metrics collection for monitoring
- **ServiceMonitor**: Prometheus scrape configuration
- **Grafana Dashboard**: Comprehensive monitoring dashboard
- **PrometheusRule**: Alert definitions

### Resource Allocation

#### Elasticsearch Node
- CPU Request: 500m
- CPU Limit: 2 cores
- Memory Request: 2Gi
- Memory Limit: 4Gi
- JVM Heap: 1GB (Xms1g, Xmx1g)
- Storage: 10Gi (Longhorn replicated)

#### Kibana
- CPU Request: 200m
- CPU Limit: 1 core
- Memory Request: 512Mi
- Memory Limit: 1Gi

#### Elasticsearch Exporter
- CPU Request: 50m
- CPU Limit: 100m
- Memory Request: 64Mi
- Memory Limit: 128Mi

## Internal Access

### Elasticsearch Service

**Endpoint**: `https://elasticsearch-eu-es-http.elasticsearch:9200`

**Credentials**:
- Username: `elastic`
- Password: Retrieved from Kubernetes secret

```bash
# Get the password
kubectl get secret elasticsearch-eu-es-elastic-user -n elasticsearch -o jsonpath='{.data.elastic}' | base64 -d

# Test connection from within cluster
kubectl run -it --rm curl --image=curlimages/curl --restart=Never -- \
  curl -k -u elastic:PASSWORD https://elasticsearch-eu-es-http.elasticsearch:9200
```

### Certificate Configuration

Elasticsearch uses self-signed certificates for internal TLS. Subject Alternative Names (SANs) include:
- `elasticsearch-eu-es-http`
- `elasticsearch-eu-es-http.elasticsearch`
- `elasticsearch-eu-es-http.elasticsearch.svc`
- `elasticsearch-eu-es-http.elasticsearch.svc.cluster.local`
- `localhost`
- `127.0.0.1`

## Kibana Access

### Web UI

**URL**: https://kibana.eu.k3s.canhnv.com

**Credentials**:
- Username: `elastic`
- Password: Same as Elasticsearch (from secret)

**TLS Certificate**: Managed by cert-manager with `canhnv-com-prod` ClusterIssuer

### Features Available

- Index Management
- Dev Tools (Console)
- Discover (Search & Filter)
- Dashboards & Visualizations
- Stack Monitoring
- Index Lifecycle Management

## Monitoring

### Grafana Dashboard

**URL**: https://grafana.eu.k3s.canhnv.com

**Dashboard Name**: "Elasticsearch - EU Cluster"

**Metrics Tracked**:

#### Cluster Overview
- Cluster Health Status (Green/Yellow/Red)
- Number of Nodes
- Unassigned Shards
- Total Shards
- Total Documents
- Store Size

#### JVM & Resources
- JVM Heap Memory (Used vs Max)
- GC Collection Rate
- Memory Pool Usage

#### Indexing & Search
- Indexing Rate (docs/sec)
- Search Query Rate (queries/sec)
- Indexing Time
- Search Time

#### Disk & Storage
- Disk Usage Percentage
- Index Size Over Time
- Available Disk Space

### Prometheus Alerts

The following alerts are configured:

| Alert Name | Severity | Condition | For Duration |
|------------|----------|-----------|--------------|
| ElasticsearchClusterHealthRed | Critical | Cluster health is RED | 2 minutes |
| ElasticsearchClusterHealthYellow | Warning | Cluster health is YELLOW | 10 minutes |
| ElasticsearchNodesDown | Critical | Nodes < 1 | 1 minute |
| ElasticsearchUnassignedShards | Warning | Unassigned shards > 0 | 5 minutes |
| ElasticsearchDiskUsageHigh | Warning | Disk usage > 80% | 5 minutes |
| ElasticsearchDiskUsageCritical | Critical | Disk usage > 90% | 2 minutes |
| ElasticsearchJVMHeapUsageHigh | Warning | Heap usage > 85% | 5 minutes |
| ElasticsearchHighGCRate | Warning | Old GC rate > 5/sec | 5 minutes |

## Common Operations

### Check Cluster Status

```bash
# Switch to EU cluster
kubectl config use-context eu

# Check all Elasticsearch resources
kubectl get elasticsearch,kibana -n elasticsearch

# Check pod status
kubectl get pods -n elasticsearch

# Check service endpoints
kubectl get svc -n elasticsearch

# View logs
kubectl logs -n elasticsearch elasticsearch-eu-es-default-0
kubectl logs -n elasticsearch -l kibana.k8s.elastic.co/name=kibana-eu
```

### Access Elasticsearch API

```bash
# Get password
ES_PASSWORD=$(kubectl get secret elasticsearch-eu-es-elastic-user -n elasticsearch -o jsonpath='{.data.elastic}' | base64 -d)

# Port-forward to access locally
kubectl port-forward -n elasticsearch svc/elasticsearch-eu-es-http 9200:9200

# In another terminal, test the API
curl -k -u elastic:$ES_PASSWORD https://localhost:9200

# Get cluster health
curl -k -u elastic:$ES_PASSWORD https://localhost:9200/_cluster/health?pretty

# List indices
curl -k -u elastic:$ES_PASSWORD https://localhost:9200/_cat/indices?v

# Get cluster stats
curl -k -u elastic:$ES_PASSWORD https://localhost:9200/_cluster/stats?pretty
```

### Create an Index

```bash
# Create a test index
curl -k -u elastic:$ES_PASSWORD -X PUT https://localhost:9200/test-index \
  -H 'Content-Type: application/json' \
  -d '{
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 0
    }
  }'

# Index a document
curl -k -u elastic:$ES_PASSWORD -X POST https://localhost:9200/test-index/_doc \
  -H 'Content-Type: application/json' \
  -d '{
    "message": "Hello from EU cluster",
    "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
  }'

# Search documents
curl -k -u elastic:$ES_PASSWORD https://localhost:9200/test-index/_search?pretty
```

### Monitor Metrics

```bash
# Check Prometheus exporter
kubectl get pods -n elasticsearch -l app=elasticsearch-exporter

# View exporter metrics
kubectl port-forward -n elasticsearch svc/elasticsearch-exporter 9114:9114

# In another terminal
curl http://localhost:9114/metrics | grep elasticsearch_
```

## Scaling

### Vertical Scaling (Resources)

Edit the Elasticsearch resource:

```bash
kubectl edit elasticsearch elasticsearch-eu -n elasticsearch
```

Update resource requests/limits:

```yaml
spec:
  nodeSets:
    - name: default
      podTemplate:
        spec:
          containers:
            - name: elasticsearch
              resources:
                requests:
                  memory: 4Gi  # Increase from 2Gi
                  cpu: 1       # Increase from 500m
                limits:
                  memory: 8Gi  # Increase from 4Gi
                  cpu: 4       # Increase from 2
              env:
                - name: ES_JAVA_OPTS
                  value: "-Xms2g -Xmx2g"  # Increase heap
```

### Horizontal Scaling (Nodes)

Increase node count:

```bash
kubectl edit elasticsearch elasticsearch-eu -n elasticsearch
```

Update node count:

```yaml
spec:
  nodeSets:
    - name: default
      count: 3  # Increase from 1
```

**Note**: For production multi-node clusters, configure:
- Replica shards (>0)
- Node roles (master, data, ingest)
- Anti-affinity rules
- Increased storage per node

### Storage Scaling

```bash
# Check current PVC
kubectl get pvc -n elasticsearch

# Expand volume (if storage class supports it)
kubectl patch pvc elasticsearch-data-elasticsearch-eu-es-default-0 \
  -n elasticsearch \
  -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
```

## Backup & Recovery

### Snapshot Repository

Configure snapshot repository for backups:

```bash
# Create S3 snapshot repository via Kibana or API
curl -k -u elastic:$ES_PASSWORD -X PUT https://localhost:9200/_snapshot/backup_repository \
  -H 'Content-Type: application/json' \
  -d '{
    "type": "s3",
    "settings": {
      "bucket": "elasticsearch-backups",
      "region": "eu-central-1",
      "base_path": "eu-cluster"
    }
  }'
```

### Create Snapshot

```bash
# Create a snapshot
curl -k -u elastic:$ES_PASSWORD -X PUT https://localhost:9200/_snapshot/backup_repository/snapshot_1?wait_for_completion=true

# List snapshots
curl -k -u elastic:$ES_PASSWORD https://localhost:9200/_snapshot/backup_repository/_all?pretty

# Get snapshot status
curl -k -u elastic:$ES_PASSWORD https://localhost:9200/_snapshot/backup_repository/snapshot_1/_status?pretty
```

### Restore from Snapshot

```bash
# Close indices before restore
curl -k -u elastic:$ES_PASSWORD -X POST https://localhost:9200/my-index/_close

# Restore snapshot
curl -k -u elastic:$ES_PASSWORD -X POST https://localhost:9200/_snapshot/backup_repository/snapshot_1/_restore

# Open indices after restore
curl -k -u elastic:$ES_PASSWORD -X POST https://localhost:9200/my-index/_open
```

## Troubleshooting

### Cluster Health is Yellow/Red

```bash
# Check cluster health
curl -k -u elastic:$ES_PASSWORD https://localhost:9200/_cluster/health?pretty

# Check unassigned shards
curl -k -u elastic:$ES_PASSWORD https://localhost:9200/_cat/shards?v | grep UNASSIGNED

# Get allocation explanation
curl -k -u elastic:$ES_PASSWORD https://localhost:9200/_cluster/allocation/explain?pretty
```

**Common Causes**:
- Replica shards on single-node cluster (set replicas to 0)
- Insufficient disk space
- Node failures
- Shard allocation issues

**Fix for single-node setup**:
```bash
# Set all indices to 0 replicas
curl -k -u elastic:$ES_PASSWORD -X PUT https://localhost:9200/_all/_settings \
  -H 'Content-Type: application/json' \
  -d '{"index": {"number_of_replicas": 0}}'
```

### Pod Crashes (OOMKilled)

Check pod events and logs:

```bash
kubectl describe pod -n elasticsearch elasticsearch-eu-es-default-0
kubectl logs -n elasticsearch elasticsearch-eu-es-default-0 --previous
```

**Solutions**:
- Increase memory limits
- Reduce JVM heap size (should be ~50% of container memory)
- Check for memory leaks in queries

### High Disk Usage

```bash
# Check disk usage
curl -k -u elastic:$ES_PASSWORD https://localhost:9200/_cat/allocation?v

# Delete old indices
curl -k -u elastic:$ES_PASSWORD -X DELETE https://localhost:9200/old-index-*

# Force merge indices to reclaim space
curl -k -u elastic:$ES_PASSWORD -X POST https://localhost:9200/_forcemerge?only_expunge_deletes=true
```

### Slow Queries

```bash
# Check slow logs
kubectl logs -n elasticsearch elasticsearch-eu-es-default-0 | grep SLOW

# Get current search performance
curl -k -u elastic:$ES_PASSWORD https://localhost:9200/_nodes/stats/indices/search?pretty

# Enable slow log
curl -k -u elastic:$ES_PASSWORD -X PUT https://localhost:9200/_all/_settings \
  -H 'Content-Type: application/json' \
  -d '{
    "index.search.slowlog.threshold.query.warn": "10s",
    "index.search.slowlog.threshold.query.info": "5s"
  }'
```

### ECK Operator Issues

```bash
# Check operator status
kubectl get pods -n elastic-system

# View operator logs
kubectl logs -n elastic-system deployment/elastic-operator

# Restart operator if needed
kubectl rollout restart deployment/elastic-operator -n elastic-system
```

### Certificate Issues

```bash
# Check certificate
kubectl get secret elasticsearch-eu-es-http-certs-public -n elasticsearch -o yaml

# Regenerate certificates (triggers rolling restart)
kubectl delete secret elasticsearch-eu-es-http-certs-internal -n elasticsearch
```

## Security Considerations

### Network Policies

Consider implementing network policies to restrict access:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: elasticsearch-netpol
  namespace: elasticsearch
spec:
  podSelector:
    matchLabels:
      elasticsearch.k8s.elastic.co/cluster-name: elasticsearch-eu
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: your-app-namespace
      ports:
        - protocol: TCP
          port: 9200
```

### User Management

Create additional users via Kibana or API:

```bash
# Create a read-only user
curl -k -u elastic:$ES_PASSWORD -X POST https://localhost:9200/_security/user/readonly_user \
  -H 'Content-Type: application/json' \
  -d '{
    "password": "changeme",
    "roles": ["viewer"]
  }'
```

### Audit Logging

Enable audit logging for compliance:

```yaml
spec:
  nodeSets:
    - config:
        xpack.security.audit.enabled: true
```

## Performance Tuning

### Index Settings

```bash
# Optimize for write performance
curl -k -u elastic:$ES_PASSWORD -X PUT https://localhost:9200/my-index/_settings \
  -H 'Content-Type: application/json' \
  -d '{
    "index": {
      "refresh_interval": "30s",
      "number_of_replicas": 0
    }
  }'

# Optimize for search performance
curl -k -u elastic:$ES_PASSWORD -X PUT https://localhost:9200/my-index/_settings \
  -H 'Content-Type: application/json' \
  -d '{
    "index": {
      "refresh_interval": "1s",
      "number_of_replicas": 1
    }
  }'
```

### JVM Tuning

Edit Elasticsearch resource to adjust JVM settings:

```yaml
env:
  - name: ES_JAVA_OPTS
    value: "-Xms2g -Xmx2g -XX:+UseG1GC"
```

## Related Documentation

- [EU Cluster Overview](./README.md)
- [Monitoring Guide](../../INFRASTRUCTURE.md#monitoring)
- [Security Guidelines](../../SECURITY_GUIDELINES.md)
- [ECK Documentation](https://www.elastic.co/guide/en/cloud-on-k8s/current/index.html)
- [Elasticsearch Reference](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)

## Deployment Commands

### Initial Deployment

```bash
# Deploy without Kibana
/Users/canhnv/development/canhnv/k3s-ansible/elasticsearch/clusters/eu/scripts/deploy.sh

# Deploy with Kibana
/Users/canhnv/development/canhnv/k3s-ansible/elasticsearch/clusters/eu/scripts/deploy.sh --with-kibana
```

### Update Deployment

```bash
# Apply configuration changes
kubectl apply -f /Users/canhnv/development/canhnv/k3s-ansible/elasticsearch/clusters/eu/elasticsearch-cluster.yaml

# Update monitoring
kubectl apply -f /Users/canhnv/development/canhnv/k3s-ansible/monitoring/clusters/eu/elasticsearch-dashboard-configmap.yaml
kubectl apply -f /Users/canhnv/development/canhnv/k3s-ansible/monitoring/clusters/eu/elasticsearch-prometheus-alerts.yaml
```

## Support & Contact

For issues or questions:
1. Check logs and metrics in Grafana
2. Review Prometheus alerts
3. Consult Elasticsearch documentation
4. Check ECK operator logs

**Monitoring**: All metrics are automatically scraped by Prometheus and visualized in the Grafana dashboard.
