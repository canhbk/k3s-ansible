# RustFS S3 Storage - SG3 Cluster

## Overview

RustFS is a high-performance S3-compatible object storage system deployed on the SG3 cluster
for application storage needs.

**Deployment Date**: 2025-01-07
**Version**: Latest (1.0.0-alpha.x)
**Mode**: Standalone

## Access

| Service | URL | Port |
|---------|-----|------|
| S3 API | https://rustfs.sg3.canhnv.com | 443 |
| Web Console | https://rustfs-console.sg3.canhnv.com | 443 |

## Credentials

Default credentials (change after first login):
- **Access Key**: rustfsadmin
- **Secret Key**: (see values.yaml or Kubernetes secret)

## Storage

- **Storage Class**: longhorn
- **Capacity**: 15Gi
- **Replicas**: 3 (Longhorn default)

## Usage

### S3 CLI Configuration

```bash
aws configure --profile rustfs-sg3
# AWS Access Key ID: rustfsadmin
# AWS Secret Access Key: <your-secret-key>
# Default region name: us-east-1
# Default output format: json

# Set endpoint URL
export AWS_ENDPOINT_URL=https://rustfs.sg3.canhnv.com
```

### Create Bucket

```bash
aws s3 mb s3://my-bucket --endpoint-url https://rustfs.sg3.canhnv.com --profile rustfs-sg3
```

### Upload File

```bash
aws s3 cp myfile.txt s3://my-bucket/ --endpoint-url https://rustfs.sg3.canhnv.com --profile rustfs-sg3
```

## Helm Deployment

### Install

```bash
helm repo add rustfs https://charts.rustfs.com/
helm repo update
helm install rustfs rustfs/rustfs -n rustfs --create-namespace -f values.yaml
kubectl apply -f ingress.yaml
```

### Upgrade

```bash
helm upgrade rustfs rustfs/rustfs -n rustfs -f values.yaml
```

### Uninstall

```bash
helm uninstall rustfs -n rustfs
kubectl delete pvc -n rustfs --all
kubectl delete namespace rustfs
```

## Management

### Check Status

```bash
kubectl get pods -n rustfs
kubectl get pvc -n rustfs
kubectl get ingress -n rustfs
kubectl logs -n rustfs deployment/rustfs
```

## Files

- `values.yaml` - Helm chart values
- `ingress.yaml` - Traefik ingress configuration
