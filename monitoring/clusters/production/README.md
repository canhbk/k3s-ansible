# Production Cluster Monitoring Template

This directory contains template files for deploying monitoring to production clusters.

## Production Clusters

- **eu**: Europe region
- **jp**: Japan/Asia region
- **sg**: Singapore primary
- **sg2**: Singapore secondary
- **us**: United States region
- **vn**: Vietnam primary
- **vn2**: Vietnam secondary

## Setup Instructions

For each production cluster:

1. Create a directory: `mkdir ../CLUSTER_NAME`

2. Copy templates:

   ```bash
   cp values-template.yaml ../CLUSTER_NAME/values.yaml
   cp ingress-template.yaml ../CLUSTER_NAME/ingress.yaml
   ```

3. Edit `values.yaml`:
   - Replace `CLUSTER_NAME` with actual cluster name
   - Replace `REGION` with actual region
   - Adjust resource limits based on cluster capacity
   - Configure alerting channels

4. Edit `ingress.yaml`:
   - Replace `CLUSTER_NAME` with actual cluster name
   - Update ClusterIssuer if using production certificates

5. Deploy:

   ```bash
   cd ../../..
   ./scripts/deploy.sh CLUSTER_NAME
   ```

## Production Considerations

### High Availability

- Consider running multiple replicas of Prometheus (with proper storage)
- Use multiple Alertmanager replicas (requires cluster peering)
- For Grafana HA, use external database (PostgreSQL/MySQL)

### Resource Sizing

Recommended starting points:

- Small clusters (< 50 nodes): Use template defaults
- Medium clusters (50-200 nodes): Double the resources
- Large clusters (> 200 nodes): Custom sizing required

### Storage

- Monitor storage usage regularly
- Consider using cloud storage classes if available
- Implement backup strategies for Grafana dashboards

### Security

- Use production TLS certificates
- Implement RBAC for Grafana users
- Secure Alertmanager webhook endpoints
- Consider network policies

### Alerting

Configure appropriate notification channels:

- Email (SMTP)
- Slack
- PagerDuty
- OpsGenie
- Custom webhooks

## Monitoring Production Services

Ensure all production services have:

1. Proper ServiceMonitor definitions
2. Meaningful metrics exposed
3. Appropriate alerting rules
4. Runbook URLs in alert annotations
