# K3s Ansible Documentation

Welcome to the comprehensive documentation for the K3s Ansible infrastructure project. This documentation covers all aspects of managing multiple K3s clusters across different environments.

## 📚 Documentation Structure

### Core Documentation

- **[Clusters Overview](./CLUSTERS_OVERVIEW.md)** - Master list of all 8 K3s clusters with access details
- **[Infrastructure Overview](./INFRASTRUCTURE.md)** - Common patterns, storage, networking, and architecture
- **[Security Guidelines](./SECURITY_GUIDELINES.md)** - Environment-specific security practices and policies

### Cluster-Specific Documentation

#### Development

- **[Dev Cluster](./clusters/dev/README.md)** - Development environment details
- **[Dev PostgreSQL](./clusters/dev/POSTGRESQL.md)** - PostgreSQL setup and access in dev

#### Production

- **[Production Guidelines](./clusters/production/README.md)** - Production cluster best practices

#### CI/CD Infrastructure

- **[VN2 GitHub Runners](./clusters/vn2/GITHUB_RUNNERS.md)** - Self-hosted runner fleet documentation
- **[VN2 Overview](./clusters/vn2/README.md)** - VN2 infrastructure overview

### Service Documentation

#### Authentication

- **[oauth2-proxy Overview](./services/oauth2-proxy/README.md)** - Centralized OAuth2 authentication proxy
- **[oauth2-proxy Deployment](./services/oauth2-proxy/DEPLOYMENT.md)** - Deploy oauth2-proxy to clusters
- **[Protecting Services](./services/oauth2-proxy/PROTECTING_SERVICES.md)** - Secure services with OAuth2

#### PostgreSQL

- **[PostgreSQL Exposure Guide](./services/postgresql/EXPOSURE.md)** - How to safely expose PostgreSQL
- **[PostgreSQL Setup](./services/postgresql/SETUP.md)** - General PostgreSQL configuration
- **[PostgreSQL Security](./services/postgresql/SECURITY.md)** - Database security practices

## 🚀 Quick Start

### Access a Cluster

```bash
# List all available clusters
kubectl config get-contexts

# Switch to development cluster
kubectl config use-context dev

# Verify connection
kubectl cluster-info
```

### Common Tasks

1. **Deploy to a cluster**: See inventory files and use Ansible playbooks
2. **Expose a service**: Follow environment-specific guidelines in [Security Guidelines](./SECURITY_GUIDELINES.md)
3. **Access PostgreSQL**: See [Dev PostgreSQL Guide](./clusters/dev/POSTGRESQL.md)
4. **Monitor services**: Use SigNoz at `signoz.dev.canhnv.com` (dev cluster)

## 🔒 Security First

Different environments have different security requirements:

- **🟢 Development**: Relaxed for productivity
- **🟡 Staging**: Production-like security
- **🔴 Production**: Maximum security enforcement

Always check the [Security Guidelines](./SECURITY_GUIDELINES.md) before making changes.

## 📊 Current Infrastructure

### Clusters by Region

- **Americas**: `us`, `dev`
- **Europe**: `eu`
- **Asia-Pacific**: `jp`, `sg`, `sg2`, `vn`, `vn2`

### Key Technologies

- **Kubernetes**: K3s lightweight distribution
- **Storage**: Longhorn distributed storage
- **Ingress**: Traefik with automatic HTTPS
- **Databases**: PostgreSQL with CloudNative PG
- **Monitoring**: SigNoz, Rancher

## 🛠️ Maintenance

### Regular Tasks

1. **Update documentation** when infrastructure changes
2. **Review exposed services** weekly in development
3. **Audit access logs** in production
4. **Rotate credentials** according to policy

### Emergency Procedures

See cluster-specific documentation for:

- Incident response
- Backup/restore procedures
- Disaster recovery plans

## 📝 Contributing to Docs

When updating documentation:

1. **Be specific**: Include actual commands and configurations
2. **Consider environment**: Clearly mark dev/staging/prod differences
3. **Add examples**: Real-world usage helps understanding
4. **Update timestamps**: Note when configurations were last verified
5. **Cross-reference**: Link to related documentation

## 🔗 External Resources

- [K3s Documentation](https://docs.k3s.io/)
- [CloudNative PG](https://cloudnative-pg.io/)
- [Longhorn Documentation](https://longhorn.io/docs/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)

## 📞 Support

For questions or issues:

1. Check cluster-specific documentation
2. Review service guides
3. Consult security guidelines
4. Contact the infrastructure team

---

*Last updated: January 2025*
*Maintained by: Infrastructure Team*
