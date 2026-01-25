# Elasticsearch Deployments

This directory contains configurations for deploying Elasticsearch clusters using ECK (Elastic Cloud on Kubernetes) operator.

## Directory Structure

```
elasticsearch/
├── README.md                    # This file
├── base/                        # Base configurations
│   ├── namespace.yaml           # Elasticsearch namespace
│   └── eck-operator/
│       └── install.sh           # ECK operator installation script
└── clusters/                    # Cluster-specific configurations
    └── eu/                      # EU cluster deployment
        ├── elasticsearch-cluster.yaml    # Elasticsearch cluster definition
        ├── elasticsearch-exporter.yaml   # Prometheus exporter
        ├── servicemonitor.yaml           # ServiceMonitor for Prometheus
        ├── kibana.yaml                   # Kibana deployment
        ├── ingress.yaml                  # Kibana ingress
        └── scripts/
            └── deploy.sh                 # Deployment script
```

## Deployments

| Cluster | Version | Nodes | Storage | Status |
|---------|---------|-------|---------|--------|
| EU | 8.17.0 | 1 | 10Gi (longhorn-replicated) | Deployed |

## ECK Operator

Version: 2.16.1

The ECK operator manages Elasticsearch and Kibana lifecycle including:
- Deployment and scaling
- Rolling upgrades
- TLS certificate management
- User authentication

### Install ECK Operator

```bash
./base/eck-operator/install.sh <cluster-context>
```

## Deploy Elasticsearch to a Cluster

### EU Cluster

```bash
# Basic deployment
./clusters/eu/scripts/deploy.sh

# With Kibana
./clusters/eu/scripts/deploy.sh --with-kibana
```

## Access Credentials

After deployment, retrieve the `elastic` user password:

```bash
kubectl get secret <cluster-name>-es-elastic-user -n elasticsearch \
  -o jsonpath='{.data.elastic}' | base64 -d
```

## Adding New Clusters

1. Create directory: `clusters/<cluster-name>/`
2. Copy and modify configurations from existing cluster
3. Update storage class, resource limits, and ingress host
4. Run the deploy script

## Documentation

- [EU Cluster Elasticsearch](../docs/clusters/eu/ELASTICSEARCH.md)
