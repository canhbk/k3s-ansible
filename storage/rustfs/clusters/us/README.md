# RustFS S3 Storage - US Cluster

## Overview

RustFS S3-compatible object storage deployed on the US (United States) cluster.

## Access URLs

| Service | URL |
|---------|-----|
| S3 API | https://rustfs.us.canhnv.com |
| Web Console | https://rustfs-console.us.canhnv.com |

## Storage Configuration

- **Storage Class**: longhorn
- **Data Volume**: 25Gi
- **Log Volume**: 1Gi
- **Longhorn Replicas**: 2 (based on cluster configuration)

## Credentials

Retrieve credentials from Kubernetes secret:

```bash
kubectl config use-context us

# Get access key
kubectl get secret rustfs-secret -n rustfs -o jsonpath='{.data.access_key}' | base64 -d

# Get secret key
kubectl get secret rustfs-secret -n rustfs -o jsonpath='{.data.secret_key}' | base64 -d
```

## AWS CLI Configuration

Add to `~/.aws/credentials`:

```ini
[rustfs-us]
aws_access_key_id = rustfsadmin
aws_secret_access_key = <secret_key_from_above>
```

Add to `~/.aws/config`:

```ini
[profile rustfs-us]
region = us-east-1
output = json
```

## Usage Examples

### AWS CLI

```bash
# List buckets
aws s3 ls --endpoint-url https://rustfs.us.canhnv.com --profile rustfs-us

# Create bucket
aws s3 mb s3://my-bucket --endpoint-url https://rustfs.us.canhnv.com --profile rustfs-us

# Upload file
aws s3 cp ./file.txt s3://my-bucket/ --endpoint-url https://rustfs.us.canhnv.com --profile rustfs-us

# Download file
aws s3 cp s3://my-bucket/file.txt ./downloaded.txt --endpoint-url https://rustfs.us.canhnv.com --profile rustfs-us
```

### Python (boto3)

```python
import boto3

s3 = boto3.client(
    's3',
    endpoint_url='https://rustfs.us.canhnv.com',
    aws_access_key_id='rustfsadmin',
    aws_secret_access_key='<secret_key>'
)

# List buckets
response = s3.list_buckets()
for bucket in response['Buckets']:
    print(bucket['Name'])

# Upload file
s3.upload_file('local_file.txt', 'my-bucket', 'remote_file.txt')

# Download file
s3.download_file('my-bucket', 'remote_file.txt', 'local_file.txt')
```

## Deployment Commands

```bash
# Switch to US context
kubectl config use-context us

# Create namespace
kubectl create namespace rustfs

# Install RustFS via Helm
helm repo add rustfs https://charts.rustfs.com/
helm repo update
helm install rustfs rustfs/rustfs -n rustfs -f values.yaml

# Wait for pod ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=rustfs -n rustfs --timeout=300s

# Apply ingress
kubectl apply -f ingress.yaml
```

## Verification

```bash
# Check pods
kubectl get pods -n rustfs

# Check PVCs
kubectl get pvc -n rustfs

# Check ingress and certificates
kubectl get ingress,certificate -n rustfs

# Test S3 API (should return 403 - access denied without credentials)
curl -I https://rustfs.us.canhnv.com

# Test Console (should return 200)
curl -I https://rustfs-console.us.canhnv.com
```

## Troubleshooting

### Pod not starting

```bash
# Check pod status
kubectl describe pod -l app.kubernetes.io/name=rustfs -n rustfs

# Check events
kubectl get events -n rustfs --sort-by='.lastTimestamp'
```

### PVC pending

```bash
# Check Longhorn status
kubectl get volumes.longhorn.io -n longhorn-system
```

### Certificate issues

```bash
# Check certificate status
kubectl get certificate -n rustfs
kubectl describe certificate -n rustfs
```
