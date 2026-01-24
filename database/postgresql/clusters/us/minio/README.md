# MinIO Deployment for PostgreSQL WAL Archiving - US Cluster

## Overview

This directory contains Kubernetes manifests for deploying MinIO to support PostgreSQL Write-Ahead Log (WAL) archiving in the US cluster.

## Prerequisites

- Kubernetes cluster with MetalLB or similar LoadBalancer implementation
- Sufficient storage for 100Gi PersistentVolumeClaim
- kubectl configured to access the cluster

## Deployment Steps

1. **Create Namespace**
   ```bash
   kubectl apply -f namespace.yaml
   ```

2. **Create Secrets**
   ```bash
   kubectl apply -f minio-secrets.yaml
   ```
   Note: Change default credentials before deployment!

3. **Deploy MinIO**
   ```bash
   kubectl apply -f minio-deployment.yaml
   kubectl apply -f minio-service.yaml
   ```

## Configuration Details

- **Namespace**: `minio`
- **Storage**: 100Gi PersistentVolumeClaim
- **Services**:
  - `minio-internal`: ClusterIP for internal cluster access
  - `minio-console`: ClusterIP for MinIO console
  - `minio-external`: LoadBalancer for external access

## Ports

- **API Port**: 9000
- **Console Port**: 9090

## Accessing MinIO

1. **Internal Access**
   - Use `minio-internal.minio.svc.cluster.local:9000` for API
   - Use `minio-console.minio.svc.cluster.local:9090` for console

2. **External Access**
   - Check the assigned external IP:
     ```bash
     kubectl get svc minio-external -n minio
     ```

## Security Recommendations

- Change default credentials in `minio-secrets.yaml`
- Use network policies to restrict access
- Enable TLS for external access
- Regularly rotate credentials

## Monitoring

Add appropriate Prometheus ServiceMonitor or configure your monitoring stack to track MinIO metrics.

## Troubleshooting

- Check pod status: `kubectl get pods -n minio`
- View logs: `kubectl logs -n minio -l app=minio`

## Updates

Periodically update the MinIO image to the latest stable version.