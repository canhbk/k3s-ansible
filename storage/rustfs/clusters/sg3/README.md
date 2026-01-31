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
- **Longhorn Replicas**: 1 (reduced from default 3 due to cluster disk pressure)

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

## Bucket Policies

### Public Buckets

The following buckets are configured with public read access for anonymous GetObject requests:

| Bucket Name | Purpose | Policy File | Public URL Pattern |
|-------------|---------|-------------|-------------------|
| `murror-articles-alpha` | Alpha environment article storage | `bucket-policy-murror-articles-alpha.json` | `https://rustfs.sg3.canhnv.com/murror-articles-alpha/{path}` |
| `murror-articles-preview` | Preview environment article storage | `bucket-policy-murror-articles-preview.json` | `https://rustfs.sg3.canhnv.com/murror-articles-preview/{path}` |

**Security Notes:**
- Directory listing (ListBucket) is denied for security
- Only GetObject requests are allowed
- Objects are accessible via direct URL without authentication
- Useful for serving public assets like article cover images

### Applying Bucket Policies

Using Python with boto3:

```python
import boto3
import json
from botocore.client import Config

s3_client = boto3.client(
    's3',
    endpoint_url='https://rustfs.sg3.canhnv.com',
    aws_access_key_id='rustfsadmin',
    aws_secret_access_key='__REDACTED__',
    config=Config(signature_version='s3v4'),
    verify=True
)

# Read and apply policy
with open('bucket-policy-murror-articles-alpha.json', 'r') as f:
    policy = json.load(f)

s3_client.put_bucket_policy(
    Bucket='murror-articles-alpha',
    Policy=json.dumps(policy)
)
```

### Testing Public Access

```bash
# Test file access (should return HTTP 200)
curl -I "https://rustfs.sg3.canhnv.com/murror-articles-alpha/path/to/file.jpg"

# Test directory listing (should return HTTP 403)
curl -I "https://rustfs.sg3.canhnv.com/murror-articles-alpha/"

# Test non-existent file (should return HTTP 404)
curl -I "https://rustfs.sg3.canhnv.com/murror-articles-alpha/nonexistent.jpg"
```

## Files

- `values.yaml` - Helm chart values
- `ingress.yaml` - Traefik ingress configuration
- `bucket-policy-murror-articles-alpha.json` - Public read policy for alpha bucket
- `bucket-policy-murror-articles-preview.json` - Public read policy for preview bucket

## Migration History

- **2026-01-31**: Reduced Longhorn replica count from 3 to 1 (volume faulted due to insufficient disk space for multi-replica scheduling)
- **2026-01-29**: Configured public read access for `murror-articles-alpha` and `murror-articles-preview` buckets
- **2025-01-28**: Migrated from `local-path` (256Mi) to `longhorn` (15Gi) storage class for better data resilience
- **2025-01-07**: Initial deployment with local-path storage

## Notes

The RustFS Helm chart uses `storageclass.name` parameter instead of the more common `persistence.storageClass`. See values.yaml for correct configuration.

RustFS uses S3v4 signature for authentication. Use `--api s3v4` or `Config(signature_version='s3v4')` when configuring S3 clients.
