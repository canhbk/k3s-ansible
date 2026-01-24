# `k3s-ansible` changelog (`k3s.orchestration`)

## 2025-11-12

### Fixed

- **rabbitmq/VN cluster**: Fixed SSL certificate error (Cloudflare Error 526) for rabbitmq.ambercare.app
  - Root cause: RabbitMQ was using Let's Encrypt staging certificates which are not trusted by browsers or Cloudflare
  - Initial Helm upgrade to chart 16.0.14 caused ImagePullBackOff (image not available in public registry)
  - Solution: Rolled back to revision 1 (chart 16.0.11, app 4.1.2) which uses available image
  - Updated ingress annotation from `ambercare-app-staging` to `ambercare-app` (production)
  - Deleted old staging certificate and secret, forcing regeneration with production issuer
  - New production certificate successfully issued by Let's Encrypt R12
  - Certificate valid from Nov 12 2025 to Feb 10 2026
  - Current deployment: Chart 16.0.11, App Version 4.1.2, Revision 3 (rolled back)
  - Created comprehensive documentation at `docs/clusters/vn/RABBITMQ.md`
  - Created VN-specific configuration directory structure at `rabbitmq/clusters/vn/`

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
