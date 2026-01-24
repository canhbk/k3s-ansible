# Kubernetes Cluster RBAC Configurations

This directory contains Role-Based Access Control (RBAC) configurations for all Kubernetes clusters in the infrastructure.

## Directory Structure

```
cluster-rbac/
├── clusters/
│   ├── dev/              # Development cluster RBAC
│   │   ├── dev-logger/   # Cluster-wide log reader access
│   │   └── mur-developers/ # Namespace-restricted developer access
│   ├── prod-ai/          # Production AI team log access
│   ├── eu/               # EU cluster (placeholder)
│   ├── jp/               # Japan cluster (placeholder)
│   ├── sg/               # Singapore cluster (placeholder)
│   ├── sg2/              # Singapore 2 cluster (placeholder)
│   ├── us/               # US cluster (placeholder)
│   ├── vn/               # Vietnam cluster (placeholder)
│   └── vn2/              # Vietnam 2 cluster (placeholder)
└── README.md             # This file
```

## Available Clusters

| Cluster | Status | RBAC Configurations | Documentation |
|---------|--------|---------------------|---------------|
| dev | ✅ Active | 2 configs (dev-logger, mur-developers) | [clusters/dev/README.md](clusters/dev/README.md) |
| prod-ai | ✅ Active | 1 config (AI team log access) | [clusters/prod-ai/README.md](clusters/prod-ai/README.md) |
| eu | 📋 Placeholder | None | [clusters/eu/README.md](clusters/eu/README.md) |
| jp | 📋 Placeholder | None | [clusters/jp/README.md](clusters/jp/README.md) |
| sg | 📋 Placeholder | None | [clusters/sg/README.md](clusters/sg/README.md) |
| sg2 | 📋 Placeholder | None | [clusters/sg2/README.md](clusters/sg2/README.md) |
| us | 📋 Placeholder | None | [clusters/us/README.md](clusters/us/README.md) |
| vn | 📋 Placeholder | None | [clusters/vn/README.md](clusters/vn/README.md) |
| vn2 | 📋 Placeholder | None | [clusters/vn2/README.md](clusters/vn2/README.md) |

## Quick Start

### For Dev Cluster

1. **Namespace-restricted developer access** (recommended):
   ```bash
   cd clusters/dev/mur-developers
   # See README.md for detailed setup
   ```

2. **Cluster-wide log reader access**:
   ```bash
   cd clusters/dev/dev-logger
   # See README.md for detailed setup
   ```

### For Production AI Team

```bash
cd clusters/prod-ai
# See README.md for setup
```

## Creating New RBAC Configurations

To add RBAC configuration for a new cluster or service:

1. Navigate to the appropriate cluster directory:
   ```bash
   cd clusters/<cluster-name>/
   ```

2. Create a new subdirectory for your service:
   ```bash
   mkdir <service-name>
   cd <service-name>
   ```

3. Create the necessary RBAC manifests:
   - ServiceAccount + Secret YAML
   - Role or ClusterRole YAML
   - RoleBinding or ClusterRoleBinding YAML
   - generate-kubeconfig.sh script (optional)
   - README.md with setup instructions

4. Follow the examples in `clusters/dev/` for structure and best practices.

## RBAC Best Practices

### Security Guidelines

1. **Principle of Least Privilege**
   - Grant only the minimum permissions required
   - Use namespace-scoped Roles instead of ClusterRoles when possible
   - Prefer read-only access unless write access is necessary

2. **Sensitive Data Management**
   - Never commit kubeconfig files with tokens to version control
   - All `*.kubeconfig.yaml` files are gitignored
   - Store credentials securely (1Password, Vault, etc.)

3. **Documentation**
   - Always create a README.md for each RBAC configuration
   - Document the purpose, permissions, and setup instructions
   - Include troubleshooting steps

4. **Naming Conventions**
   - ServiceAccounts: `<service>-<purpose>` (e.g., `mur-developers`, `dev-logger`)
   - Roles: `<service>-<purpose>-role` (e.g., `dev-namespaces-reader`)
   - RoleBindings: `<service>-<purpose>-binding`

### Common RBAC Patterns

| Pattern | Use Case | Example |
|---------|----------|---------|
| Namespace-scoped Role | Restrict access to specific namespaces | `clusters/dev/mur-developers/` |
| ClusterRole | Cluster-wide access (logs, metrics) | `clusters/dev/dev-logger/` |
| ServiceAccount per service | Separate credentials per service | All current configs |
| Read-only access | Developers, monitoring tools | All current configs |

## Troubleshooting

### Access Denied Errors

1. Verify the ServiceAccount exists:
   ```bash
   kubectl get sa -n <namespace> <service-account-name>
   ```

2. Check if Role/ClusterRole exists:
   ```bash
   kubectl get role -n <namespace> <role-name>
   # or
   kubectl get clusterrole <clusterrole-name>
   ```

3. Verify RoleBinding/ClusterRoleBinding:
   ```bash
   kubectl get rolebinding -n <namespace> <binding-name>
   # or
   kubectl get clusterrolebinding <binding-name>
   ```

4. Test permissions:
   ```bash
   kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<namespace>:<serviceaccount> -n <namespace>
   ```

### Token Issues

If tokens become invalid:
1. Delete and recreate the Secret
2. Regenerate the kubeconfig using the generate script
3. Distribute new kubeconfig to users

## Security Notes

⚠️ **Important Security Reminders**:
- All `*.kubeconfig.yaml` files contain sensitive authentication tokens
- These files are automatically excluded from version control via `.gitignore`
- Treat kubeconfig files like passwords - never share publicly
- Rotate tokens regularly for production environments
- Use dedicated ServiceAccounts per service/team

## Contributing

When adding new RBAC configurations:
1. Follow the directory structure conventions
2. Create comprehensive README documentation
3. Test the configuration before committing
4. Update this main README to list your new configuration
5. Commit with descriptive commit messages

## References

- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [K3s RBAC](https://docs.k3s.io/security/hardening-guide#rbac)
- Project documentation: `docs/SECURITY_GUIDELINES.md`

---

Last updated: 2025-11-04
