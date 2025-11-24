# Dev Cluster RBAC Configurations

This directory contains all RBAC configurations for the dev Kubernetes cluster.

## Overview

The dev cluster has two main RBAC configurations for different access patterns:

### 1. mur-developers/ - Namespace-Restricted Developer Access

Provides developers with read-only access to specific namespaces using namespace-scoped Roles.

**Target Namespaces**:
- mu-43, mu-66, mu-69, mu-70, mu-81
- nsp-alpha-murror, nsp-alpha-murror-ai

**Access Type**: Read-only (namespace-restricted)

**Documentation**: See `mur-developers/README.md`

### 2. dev-logger/ - Cluster-Wide Log Reader Access

Provides cluster-wide log reader access for centralized logging and monitoring.

**Access Type**: Read-only (cluster-wide logs)

**Documentation**: See `dev-logger/README.md`

## When to Use Which Configuration

| Use Case | Configuration | Reason |
|----------|--------------|--------|
| Developer debugging specific namespaces | `mur-developers/` | Namespace-restricted, principle of least privilege |
| Centralized logging/monitoring | `dev-logger/` | Needs cluster-wide log access |
| CI/CD pipelines | Create new config | Specific to CI/CD needs |
| Read-only production access | Create new config | Production should not use dev configs |

## Adding New RBAC Configurations

To add a new RBAC configuration:

1. Create a new subdirectory: `clusters/dev/<service-name>/`
2. Add your RBAC manifests (ServiceAccount, Role/ClusterRole, Bindings)
3. Create a README.md explaining the purpose and setup
4. Add a generate-kubeconfig.sh script if needed
5. Update this README to list the new configuration

## Security Best Practices

- Always use namespace-scoped Roles when possible (not ClusterRoles)
- Implement principle of least privilege
- Never commit kubeconfig files with tokens to version control
- Use read-only permissions unless write access is absolutely necessary
- Document all RBAC configurations thoroughly

## Cluster Information

- **Master Node**: vps5-h2cloud-vn (180.93.96.54)
- **API Endpoint**: https://180.93.96.54:6443
- **Context Name**: dev
- **Worker Nodes**: 5 nodes (vps12, vps13, vps16, vps17, vps18)

Last updated: 2025-11-24 (IP changes from VPS provider)
