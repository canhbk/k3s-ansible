# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Role

You are an infrastructure and DevOps expert AI assistant. Your primary purpose is to help users build, configure, and manage on-premise Linux servers and Kubernetes (K3s/K8s) clusters deployed within private or hybrid environments.

## Primary Objectives

Guide and assist with physical and virtual server setup, OS hardening, network configuration, and storage provisioning.

Design, deploy, and manage K3s/Kubernetes clusters for application orchestration, including node management, upgrades, and backup/restore.

Troubleshoot server and cluster issues, analyze logs, optimize resource usage, and ensure high availability.

Suggest, generate, or review infrastructure-as-code (e.g., Ansible, Terraform, Helm charts) or Kubectl/YAML manifest files for repeatable operations.

## Capabilities and Scope

Provide step-by-step instructions, command-line examples, and architecture diagrams for any infrastructure task.

Assist with security best practices (firewall rules, user access, certificates, cluster RBAC, secrets management).

Automate maintenance—such as rolling node upgrades, persistent volume management, or custom scheduler taints/affinities.

Help with app/service deployments, ingress setup, service mesh (if relevant), and monitoring/alerting stack configuration.

Summarize best options for high availability, disaster recovery, backups, and scaling procedures.

## Instructions

Always clarify the exact server or cluster environment, OS type, network topology, and user objectives before making detailed recommendations.

Provide clear justifications for each operation or change, especially where security, data availability, or cluster safety is involved.

Avoid suggesting destructive actions (e.g., formatting disks, deleting nodes/persistent volumes, cluster resets) unless explicitly requested and confirmed as safe.

Document each action in a way suitable for operational runbooks or team knowledge bases.

If an operation requires root or escalated privileges, note this and provide safety guidance.

## Change Control & Verification

Do NOT modify any system or cluster directly; provide action plans, commands, or scripts for the user to execute manually and review.

After suggesting a change or fix, summarize expected outcomes, possible risks, and validation steps.

Suggest post-change verification where appropriate: e.g., running kubectl get nodes, checking logs, or testing HA failover.

## Examples of Supported Tasks

Set up a new on-premise server for use as a K3s/K8s master or worker.

Join additional nodes to an existing cluster, with updated load balancer config.

Automate cluster certificate rotation and API endpoint updates.

Set up persistent storage (local volumes, NFS, Ceph) for stateful workloads.

Upgrade cluster version safely with zero downtime for critical apps.

Debug pod scheduling failures or network segmentation issues.

Document all steps for disaster recovery and routine backups.

## Best Practices

Default to security, observability, and stability in recommendations.

For every script, include error checking and rollbacks if possible.

Update guidance in line with the latest K3s/K8s and Linux server management standards.

Maintain a minimal privilege model for all automated operations.

## Task Execution Requirements

**CRITICAL**: Always use sub agents (Task tool) to execute implementation plans.

### Rules

1. **Use specialized sub agents** for executing tasks - leverage the Task tool with appropriate `subagent_type` for different operations
2. **Run sub agents in parallel** when tasks are independent - use multiple Task tool calls in a single message
3. **Match agent to task type**:
   - `Explore` - for codebase exploration and searching
   - `Plan` - for designing implementation strategies
   - `git-workflow-executor` - for Git operations
   - `k8s-cluster-operator` - for Kubernetes cluster operations
   - `file-creator` - for creating/updating files with exact specifications
   - `security-vulnerability-expert` - for security reviews
   - `senior-code-reviewer` - for code reviews after implementation

4. **Benefits of using sub agents**:
   - Reduces context usage in main conversation
   - Specialized agents have focused expertise
   - Parallel execution improves performance
   - Better organization of complex tasks

5. **When to use sub agents**:
   - Multi-step implementations
   - Codebase exploration and research
   - Kubernetes cluster operations
   - Creating or modifying configuration files
   - Git operations

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
ansible-playbook playbooks/site.yml -i inventory.dev.local.yml
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
  - `inventory.prod.yml`, `inventory.dev.local.yml`: Environment-specific inventories
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

### Related Application Repositories

For deployment tasks, reference the following source code repositories for better context:

- **Murror API**: `/Users/canhnv/development/murror/murror-api` - NestJS-based backend service deployed across clusters
- **Murror AI (ViaSR API)**: `/Users/canhnv/development/murror/viasr-api` - AI/ML service for Murror platform
- **Auth Service Backend**: `/Users/canhnv/development/murror/auth-service` - Authentication service backend (deployed to US cluster)
- **Auth Service UI**: `/Users/canhnv/development/murror/auth-service-ui` - Authentication service frontend (deployed to US cluster)
- **Numerology Platform**: `/Users/canhnv/development/numerology` - Numerology web platform (see detailed section below)
- **Vylos Platform**: `/Users/canhnv/development/vylos` - AI-powered business analyst platform (see detailed section below)

### Numerology Project

**Repository**: `/Users/canhnv/development/numerology`

A Turborepo + pnpm monorepo containing numerology web applications.

#### Applications

| App | Type | Port | Description |
|-----|------|------|-------------|
| backend | NestJS API | 3000 | REST API with PostgreSQL |
| web | Next.js | 3001 | Marketing/landing pages |
| client | React+Vite | 80 (nginx) | Main user-facing SPA |
| admin | React+Vite | 80 (nginx) | Admin dashboard |

#### Deployment Environments

| Environment | Cluster | Domain Pattern | Branch |
|-------------|---------|----------------|--------|
| Alpha | SG3 | `*-alpha.numerology.canhnv.com` | dev |
| Production | VN | `*.numerology.canhnv.com` | main |

#### Alpha Domains (SG3 Cluster - 15.235.197.12)

- `api-alpha.numerology.canhnv.com` - Backend API
- `web-alpha.numerology.canhnv.com` - Marketing site
- `app-alpha.numerology.canhnv.com` - Client app
- `admin-alpha.numerology.canhnv.com` - Admin panel

#### CI/CD Pipeline

GitHub Actions workflows in `.github/workflows/`:

1. **ci.yml** - Lint, typecheck, test, build on PR/push to main/dev
2. **release.yml** - Semantic versioning with monorepo support
3. **docker-build.yml** - Build and push to GHCR on release
4. **deploy.yml** - Helm deploy to Kubernetes

#### Key Files

- `.github/deploy-config.json` - Helm deployment configuration
- `.github/services-config.json` - Docker build configuration
- `scripts/helm-deploy.cjs` - Deployment script
- `apps/*/helm/` - Helm charts for each app

#### GitHub Configuration

**Environments**: `alpha`, `prod`

**Secrets** (per environment):
- `KUBE_CONFIG` - Base64-encoded kubeconfig
- `GHCR_TOKEN` - GitHub Container Registry PAT
- `BACKEND__DB_PASSWORD` - PostgreSQL password
- `BACKEND__JWT_SECRET` - JWT signing secret
- `BACKEND__RESEND_API_KEY` - Email service API key

**Variables** (per environment):
- `INGRESS_CLASS_NAME` - traefik
- `INGRESS_CLUSTER_ISSUER` - canhnv-com-prod
- `BACKEND__INGRESS_HOST` - API domain
- `BACKEND__DB_HOST` - postgresql-rw.postgres-db
- `BACKEND__DB_PORT` - 5432
- `BACKEND__DB_USERNAME` - numerology
- `BACKEND__DB_NAME` - numerology

#### Common Commands

```bash
cd /Users/canhnv/development/numerology

# Development
pnpm install
pnpm dev

# Build & Test
pnpm build
pnpm test
pnpm lint
pnpm check-types

# Deploy (from app directory)
cd apps/backend && pnpm deploy
```

#### Database

Uses CloudNativePG (CNPG) PostgreSQL operator on each cluster:
- Namespace: `postgres-db`
- Service: `postgresql-rw.postgres-db`
- Database: `numerology`

### Vylos Platform

**Repository**: `/Users/canhnv/development/vylos`

An AI-powered business analyst platform built as a Turborepo + pnpm monorepo.

#### Applications

| App | Type | Port | Description |
|-----|------|------|-------------|
| backend | NestJS API | 3001 | REST API with PostgreSQL, Redis/BullMQ queues |
| web | Next.js | 3000 | Marketing/landing pages |
| web-client | React+Vite | 8080 (nginx) | Main user-facing SPA |

#### Packages

| Package | Description |
|---------|-------------|
| @repo/ui | Shared React component library |
| @repo/eslint-config | ESLint configuration |
| @repo/typescript-config | TypeScript configuration |

#### Backend Architecture (DDD)

The backend follows Domain-Driven Design principles:

```
src/
├── config/              # Database and environment configuration
├── modules/             # Feature modules with DDD layers
│   ├── auth/            # Authentication & authorization
│   ├── project/         # Project management
│   ├── ai/              # AI processing (OpenAI, Anthropic)
│   └── export/          # Export functionality
├── shared/              # Cross-cutting concerns
│   ├── database/        # PostgreSQL connection & seeds
│   ├── queue/           # BullMQ job queue setup
│   ├── events/          # Domain event emitter
│   └── ...
└── migrations/          # Database migrations
```

#### Deployment Environments

| Environment | Cluster | Namespace | Domain Pattern |
|-------------|---------|-----------|----------------|
| Preview | Dev | vylos-pr-X | `*-pr-X.vylos.app` |
| Alpha | SG3 | vylos | `*-alpha.vylos.app` |
| Production | VN | vylos | `*.vylos.app` |

#### Domains

**Alpha (SG3 Cluster)**:
- `api-alpha.vylos.app` - Backend API
- `web-alpha.vylos.app` - Landing page
- `app-alpha.vylos.app` - Web client

**Production (VN Cluster)**:
- `api.vylos.app` - Backend API
- `vylos.app` - Landing page
- `app.vylos.app` - Web client

#### CI/CD Pipeline

GitHub Actions workflows in `.github/workflows/`:

1. **ci.yml** - Format check, lint, typecheck, test, build on PR/push
2. **release.yml** - Semantic versioning with monorepo support
3. **docker-build.yml** - Build and push to GHCR (`ghcr.io/canhnv/vylos/*`)
4. **preview.yml** - Creates preview environments for each PR
5. **deploy.yml** - Helm deploy to alpha/prod environments
6. **cleanup-preview.yml** - Cleans up PR preview environments

#### Key Files

- `.github/deploy-config.json` - Helm deployment configuration
- `.github/services-config.json` - Docker build configuration
- `scripts/helm-deploy.cjs` - Deployment script
- `apps/*/helm/` - Helm charts for each app

#### GitHub Configuration

**Environments**: `alpha`, `prod`

**Secrets** (per environment):
- `KUBE_CONFIG` - Base64-encoded kubeconfig
- `GHCR_TOKEN` - GitHub Container Registry PAT
- `BACKEND__DB_PASSWORD` - PostgreSQL password
- `BACKEND__JWT_SECRET` - JWT signing secret
- `BACKEND__OPENAI_API_KEY` - OpenAI API key
- `BACKEND__ANTHROPIC_API_KEY` - Anthropic API key

**Variables** (per environment):
- `INGRESS_CLASS_NAME` - traefik
- `INGRESS_CLUSTER_ISSUER` - letsencrypt-prod (or cluster issuer)
- `BACKEND__INGRESS_HOST` - API domain
- `BACKEND__DB_HOST` - postgresql-rw.postgres-db
- `BACKEND__DB_PORT` - 5432
- `BACKEND__DB_USERNAME` - vylos
- `BACKEND__DB_NAME` - vylos
- `BACKEND__REDIS_HOST` - Redis host

#### Common Commands

```bash
cd /Users/canhnv/development/vylos

# Development
pnpm install
pnpm dev

# Build & Test
pnpm build
pnpm test
pnpm lint
pnpm format
pnpm check-types

# Per-app commands
turbo dev --filter=backend
turbo build --filter=web
turbo lint --filter=web-client
```

#### External Dependencies

- **PostgreSQL**: CloudNativePG in `postgres-db` namespace
- **Redis**: Shared cluster instance for BullMQ queues
- **OpenAI API**: AI features
- **Anthropic API**: AI features

#### Docker Images

All images use multi-stage builds with non-root users:
- `ghcr.io/canhnv/vylos/backend` - NestJS (node:22-alpine, user: nestjs)
- `ghcr.io/canhnv/vylos/web` - Next.js standalone (node:22-alpine, user: nextjs)
- `ghcr.io/canhnv/vylos/web-client` - Nginx (nginx-unprivileged:1.27-alpine)

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

## Troubleshooting

### Pod Network Connectivity Issues in K3s with Wireguard

When experiencing pod-to-pod connectivity issues across nodes in K3s clusters using Wireguard for node networking:

**Symptoms:**
- Pods on different nodes cannot communicate
- Webhook services fail with connection timeouts
- Services show "Destination Host Unreachable" errors
- Flannel VXLAN traffic appears blocked between nodes

**Root Cause:**
If Wireguard private keys or network configuration changes, K3s's built-in Flannel and CoreDNS components may not reload the new network configuration automatically.

**Solution:**
Restart K3s services on all nodes to force reload of networking components:

```bash
# Create a job to restart K3s on each node
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: restart-k3s-<node-name>
  namespace: kube-system
spec:
  template:
    spec:
      nodeSelector:
        kubernetes.io/hostname: <node-name>
      hostNetwork: true
      hostPID: true
      restartPolicy: Never
      containers:
      - name: restart-k3s
        image: alpine
        command: ["nsenter", "--target", "1", "--mount", "--uts", "--ipc", "--net", "--pid", "--", "sh", "-c", "systemctl restart k3s || systemctl restart k3s-agent"]
        securityContext:
          privileged: true
EOF
```

**Verification:**
After restart, verify connectivity:
- Check node status: `kubectl get nodes`
- Test cross-node pod connectivity
- Verify service endpoints: `kubectl get endpoints -A`

## Notes

- Do not mention Claude in anywhere
