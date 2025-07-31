# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Ansible-based automation project for deploying and managing K3s Kubernetes clusters. K3s is a lightweight Kubernetes distribution designed for edge, IoT, and resource-constrained environments.

## Documentation

Comprehensive documentation is available in the `docs/` directory:
- **[Documentation Home](./docs/README.md)** - Start here for navigation
- **[Clusters Overview](./docs/CLUSTERS_OVERVIEW.md)** - All 8 clusters (dev, eu, jp, sg, sg2, us, vn, vn2)
- **[Infrastructure Guide](./docs/INFRASTRUCTURE.md)** - Architecture and patterns
- **[Security Guidelines](./docs/SECURITY_GUIDELINES.md)** - Environment-specific security

For cluster-specific information:
- **[Dev Cluster](./docs/clusters/dev/README.md)** - Development environment
- **[Dev PostgreSQL](./docs/clusters/dev/POSTGRESQL.md)** - Database access

## Important: Cluster Fleet Management & Documentation

### Discovering Clusters
This project manages 8 K3s clusters across different environments:
- **Development**: `dev`
- **Production**: `eu`, `jp`, `sg`, `sg2`, `us`, `vn`, `vn2`

To discover and verify clusters:
```bash
# List all available contexts
kubectl config get-contexts

# Check cluster connectivity
for ctx in dev eu jp sg sg2 us vn vn2; do
  kubectl config use-context $ctx
  kubectl get nodes
done

# Verify inventory files
ls inventory*.yml
```

### Documentation Maintenance Requirements

**CRITICAL**: Always update documentation to reflect any changes you make or detect in the clusters.

1. **Before Making Changes**:
   - Check current state: `kubectl get all -A | grep <resource>`
   - Review existing docs in `docs/` directory
   - Verify with actual cluster state

2. **After Making Changes**:
   - Update relevant documentation immediately
   - Include actual kubectl commands used
   - Update timestamps in docs
   - Verify changes are reflected correctly

3. **Documentation Update Checklist**:
   - [ ] Update service-specific docs (e.g., `docs/services/postgresql/`)
   - [ ] Update cluster-specific docs (e.g., `docs/clusters/dev/`)
   - [ ] Update overview docs if needed (`docs/CLUSTERS_OVERVIEW.md`)
   - [ ] Include new services in `docs/clusters/*/SERVICES.md`
   - [ ] Update security guidelines if security changes made

4. **Verification Commands**:
   ```bash
   # Before documenting, always verify:
   kubectl get nodes -o wide
   kubectl get svc -A
   kubectl get ingress -A
   kubectl get pods -A | grep <service>
   ```

### Example Documentation Update Flow

When exposing a new service:
1. Apply the change
2. Verify it works: `kubectl get svc -n <namespace> <service>`
3. Update `docs/clusters/<cluster>/SERVICES.md`
4. Update `docs/services/<service>/EXPOSURE.md` if applicable
5. Add security notes to `docs/SECURITY_GUIDELINES.md`

**Remember**: Documentation is only valuable if it's accurate. Always verify before documenting!

## Common Commands

### Cluster Deployment

```bash
# Deploy a new K3s cluster
ansible-playbook playbooks/site.yml -i inventory.yml

# Deploy with specific inventory
ansible-playbook playbooks/site.yml -i inventory.prod.yml
ansible-playbook playbooks/site.yml -i inventory.dev.yml
ansible-playbook playbooks/site.yml -i inventory.vn.yml
```

### Cluster Management

```bash
# Upgrade K3s version (update k3s_version in inventory first)
ansible-playbook playbooks/upgrade.yml -i inventory.yml

# Reboot cluster nodes (servers first, then agents)
ansible-playbook playbooks/reboot.yml -i inventory.yml

# Reset/destroy cluster completely
ansible-playbook playbooks/reset.yml -i inventory.yml
```

### Development Commands

```bash
# Install Ansible collections dependencies
ansible-galaxy collection install -r collections/requirements.yml

# Test with Vagrant (local development)
vagrant up

# Run playbook with verbose output
ansible-playbook playbooks/site.yml -i inventory.yml -vvv

# Run playbook on specific hosts
ansible-playbook playbooks/site.yml -i inventory.yml --limit server
```

## Architecture

### Ansible Structure

- **Playbooks** (`playbooks/`): Main orchestration files
  - `site.yml`: Primary deployment playbook
  - `upgrade.yml`: K3s version upgrade playbook
  - `reset.yml`: Cluster teardown playbook
  - `reboot.yml`: Node reboot orchestration

- **Roles** (`roles/`): Modular components
  - `prereq`: System prerequisites and preparation
  - `k3s_server`: K3s control plane setup
  - `k3s_agent`: K3s worker node setup
  - `k3s_upgrade`: Version upgrade logic
  - `airgap`: Airgap installation support
  - `raspberrypi`: Raspberry Pi specific configurations

- **Inventory Files**: Multiple environment configurations
  - `inventory.yml`: Main inventory (copy from inventory-sample.yml)
  - `inventory.prod.yml`, `inventory.dev.yml`: Environment-specific inventories
  - `inventory.vn.yml`, `inventory.us.yml`: Region-specific deployments

### Key Configuration Patterns

1. **HA Mode**: When multiple servers are defined in inventory, automatic HA setup with embedded etcd (requires odd number: 3, 5, 7)

2. **External Database**: Set `use_external_database: true` and provide `extra_server_args` with datastore endpoint

3. **Airgap Installation**: Place K3s binaries and images in a directory and set `airgap_dir` variable

4. **Custom Configurations**:
   - Server config via `server_config_yaml` variable
   - Registry config via `registries_config_yaml` variable
   - Extra manifests via `extra_manifests` list

### Application Stack Components

The repository includes configurations for various applications:

- **Longhorn**: Distributed storage system
- **PostgreSQL HA**: High-availability PostgreSQL clusters
- **Redis**: In-memory data store configurations
- **RabbitMQ**: Message broker setup
- **MySQL Cluster**: Database clustering
- **Cert-Manager**: TLS certificate management
- **Rancher**: Kubernetes management UI

## Important Variables

Key inventory variables to configure:

- `k3s_version`: K3s version to install/upgrade to
- `token`: Cluster join token (generate with `openssl rand -base64 64`)
- `api_endpoint`: API server endpoint (defaults to first server)
- `extra_server_args`: Additional K3s server arguments
- `extra_agent_args`: Additional K3s agent arguments
- `ansible_user`: SSH user for nodes
- `ansible_port`: SSH port (default: 22)

## Kubernetes Access

After deployment, kubeconfig is automatically:

- Copied to control node at `~/.kube/config`
- Merged under context name `k3s-ansible`

Access cluster with:

```bash
kubectl config use-context k3s-ansible
kubectl get nodes
```
