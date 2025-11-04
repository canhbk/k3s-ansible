# EU Cluster RBAC Configuration

This directory will contain RBAC configurations for the EU cluster.

## Status

No RBAC configurations defined yet.

## When to Add Configurations

Add RBAC configurations here when you need to:
- Provide developer access to specific namespaces
- Create service accounts for CI/CD pipelines
- Grant read-only access for monitoring tools
- Set up custom roles and bindings

## Examples

Refer to `clusters/dev/` for examples of well-structured RBAC configurations:
- `clusters/dev/mur-developers/` - Namespace-restricted read-only access for developers
- `clusters/dev/dev-logger/` - Cluster-wide log reader access
