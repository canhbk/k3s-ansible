# `k3s-ansible` changelog (`k3s.orchestration`)

## 2025-11-04

### Changed

- **cluster-rbac**: Major restructuring for better organization and multi-cluster management
  - Moved root-level dev-logger files to `clusters/dev/dev-logger/`
  - Organized dev cluster files into service-specific subdirectories (`dev-logger/`, `mur-developers/`)
  - Renamed `role/` to `clusters/prod-ai/` for clarity
  - Created placeholder directories for all 8 clusters (eu, jp, sg, sg2, us, vn, vn2)
  - Updated `.gitignore` to exclude sensitive kubeconfig files (`*.kubeconfig.yaml`)
  - Created comprehensive README documentation at root and cluster levels
  - Implemented consistent directory structure across all clusters

- **cluster-rbac/clusters/dev**: Migrated from cluster-wide to namespace-restricted RBAC for developer access
  - Replaced ClusterRole with namespace-scoped Roles for enhanced security
  - Replaced ClusterRoleBinding with namespace-specific RoleBindings
  - Updated for post-vps7 removal (node removal does not affect RBAC)
  - Added explicit access control for namespaces: mu-43, mu-66, mu-69, mu-70, mu-81, nsp-alpha-murror, nsp-alpha-murror-ai
  - Added namespace listing permission for discoverability (`kubectl get ns` now works)
  - Enhanced generate-mur-kubeconfig.sh with access verification and namespace listing test
  - Updated README with comprehensive setup, troubleshooting, and maintenance guides

## 1.0.0

Initial Release
