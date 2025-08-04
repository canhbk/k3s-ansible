# InfluxDB - Production Cluster Template

Template for production cluster InfluxDB deployments.

## Setup Instructions

1. **Copy this directory** to create a new cluster configuration:

   ```bash
   cp -r production <cluster-name>
   ```

2. **Update values.yaml**:
   - Replace `CLUSTER_NAME` with actual cluster name
   - Adjust storage size based on expected data volume
   - Configure storage class (especially for VN clusters using longhorn-vn)
   - Set backup destination if using S3

3. **Update ingress.yaml**:
   - Replace all instances of `CLUSTER_NAME`
   - Verify cert-manager issuer is correct

4. **Create admin secret**:

   ```bash
   # Generate secure password
   openssl rand -base64 32

   # Create admin-secret.yaml in the cluster directory
   ```

5. **Deploy**:

   ```bash
   ../../scripts/deploy.sh <cluster-name>
   ```

## Production Configuration

- **Retention**: 90 days (3 months)
- **Storage**: 100Gi (adjust based on needs)
- **Resources**: 1Gi-4Gi memory
- **Backups**: Daily automated backups with 30-day retention
- **Anti-affinity**: Prevents scheduling on same node (if replicas added)

## Monitoring

Production deployments include:

- ServiceMonitor for Prometheus
- Production log levels (warn)
- Metrics exposed for alerting

## Security

- Rate limiting enabled in ingress
- TLS required for all connections
- Token-based authentication
- Consider adding network policies
