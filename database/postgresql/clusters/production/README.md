# PostgreSQL HA - Production Clusters Template

This directory contains templates for production PostgreSQL clusters.

## Production Clusters

- **EU**: Europe region
- **JP**: Japan region
- **SG**: Singapore region
- **SG2**: Singapore region 2
- **US**: United States region
- **VN2**: Vietnam region 2

## Template Usage

1. Copy templates to the specific cluster directory:
   ```bash
   cp cluster-template.yaml ../eu/cluster.yaml
   cp secrets-template.yaml ../eu/secrets.yaml
   ```

2. Modify the configuration for your specific environment:
   - Update storage class
   - Adjust resource requests/limits
   - Configure node affinity
   - Set appropriate instance count for HA

3. Generate strong passwords for secrets

4. Deploy following the standard process

## Production Considerations

### High Availability
- Use at least 3 instances for production
- Configure proper pod anti-affinity
- Set up automated backups
- Configure monitoring and alerting

### Security
- Use strong, unique passwords
- Enable SSL/TLS
- Configure network policies
- Implement RBAC
- Regular security audits

### Performance
- Tune PostgreSQL parameters
- Monitor resource usage
- Configure connection pooling
- Regular maintenance (VACUUM, ANALYZE)

### Backup and Recovery
- Configure automated backups
- Test restore procedures
- Off-site backup storage
- Point-in-time recovery

### Monitoring
- CloudNative-PG metrics
- PostgreSQL performance metrics
- Log aggregation
- Alert configuration