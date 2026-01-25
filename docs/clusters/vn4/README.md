# VN4 Infrastructure (Vietnam Quaternary)

## Overview

> **Important**: VN4 is a dedicated GitHub Actions self-hosted runner infrastructure.

The VN4 infrastructure consists of 3 H2Cloud Vietnam VPS servers that serve as dedicated GitHub Actions self-hosted runners for CI/CD workflows.

**Last Updated**: 2026-01-25

## Infrastructure Information

- **Type**: GitHub Actions Self-Hosted Runners
- **Environment**: Production CI/CD
- **Region**: Vietnam (vn4)
- **Provider**: H2Cloud Vietnam
- **Organizations**: murror, canh-nv
- **Total Runners**: 6 (2 per node)

## Runner Infrastructure

### Runner Nodes (3)

| Hostname | External IP | Runners | Status |
|----------|-------------|---------|--------|
| vps6-h2cloud-vn | 160.191.245.246 | vn4-murror-1, vn4-canh-nv-1 | Active |
| vps13-h2cloud-vn | 160.191.245.244 | vn4-murror-2, vn4-canh-nv-2 | Active |
| vps16-h2cloud-vn | 160.191.245.234 | vn4-murror-3, vn4-canh-nv-3 | Active |

Each node runs two runner instances: one for the **murror** organization and one for the **canh-nv** organization.

## Server Specifications

- **OS**: Ubuntu 24.04 LTS
- **CPU**: 4 vCPU
- **RAM**: 9.7GB
- **Storage**: Standard disk
- **Network**: H2Cloud Vietnam datacenter

## Network Configuration

- **Outbound Access**: GitHub.com, GHCR.io, Docker Hub
- **Docker MTU**: 1400 (Wireguard optimized)
- **DNS**: 8.8.8.8, 8.8.4.4

## Deployment Method

The GitHub runners were deployed using Ansible playbooks.

See: `playbooks/setup-github-runners.yml` and `inventory.vn4-runners.yml`

### Setup Commands

```bash
# Load PAT credentials
source vn4-runners.secrets

# Deploy runners to all nodes
ansible-playbook playbooks/setup-github-runners.yml -i inventory.vn4-runners.yml
```

## Key Capabilities

> **For comprehensive documentation, see [GitHub Runners Guide](./GITHUB_RUNNERS.md)**

- **Primary Use**: CI/CD for murror and canh-nv organizations
- **Docker**: Docker-in-Docker support with Buildx
- **Node.js**: Version 22 LTS with pnpm
- **Kubernetes**: kubectl and Helm v3 for deployments
- **Build Tools**: Full C/C++ toolchain, Python 3

## Usage in Workflows

### For murror Organization

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, x64, vn4, murror]
    steps:
      - uses: actions/checkout@v4
      - run: pnpm install && pnpm build
```

### For canh-nv Organization

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, x64, vn4, canh-nv]
    steps:
      - uses: actions/checkout@v4
      - run: pnpm install && pnpm build
```

### Documentation

For comprehensive documentation including:
- Complete setup procedure
- Pre-installed software details
- Service management commands
- Troubleshooting guides
- Security best practices

See: **[GitHub Runners Documentation](./GITHUB_RUNNERS.md)**

## Access

### SSH Access

All nodes are accessible via SSH as root user for administrative tasks.

```bash
# Check runner status on a node
ssh root@160.191.245.246 "systemctl status 'actions.runner.*'"

# View runner logs
ssh root@160.191.245.246 "journalctl -u actions.runner.murror-vn4-murror-1 -f"
```

### GitHub UI

View runners in GitHub organization settings:
- **murror**: https://github.com/organizations/murror/settings/actions/runners
- **canh-nv**: https://github.com/organizations/canh-nv/settings/actions/runners

## Common Operations

### Check Runner Status

```bash
# Check all runners on all nodes
for ip in 160.191.245.246 160.191.245.244 160.191.245.234; do
  echo "=== $ip ==="
  ssh root@$ip "systemctl status 'actions.runner.*' --no-pager | grep -E '(\.service|Active:)'"
done
```

### Restart a Runner

```bash
ssh root@160.191.245.246 "systemctl restart actions.runner.murror-vn4-murror-1"
```

### Update Runner Version

```bash
# Load credentials
source vn4-runners.secrets

# Update and redeploy
ansible-playbook playbooks/setup-github-runners.yml \
  -i inventory.vn4-runners.yml \
  -e "runner_version=2.322.0" \
  -e "force_reconfigure=true"
```

## Troubleshooting

### Runner Offline

1. Check service status: `ssh root@<ip> "systemctl status actions.runner.<name>"`
2. Restart if needed: `ssh root@<ip> "systemctl restart actions.runner.<name>"`
3. Check logs: `ssh root@<ip> "journalctl -u actions.runner.<name> -n 50"`

### Jobs Not Running

1. Verify runner labels match workflow `runs-on` requirements
2. Check if runners are online in GitHub UI
3. Ensure runners are not all busy with other jobs

### Docker Issues

```bash
# Check Docker daemon
ssh root@160.191.245.246 "systemctl status docker"

# Test Docker
ssh root@160.191.245.246 "docker run --rm hello-world"

# Clean up disk space
ssh root@160.191.245.246 "docker system prune -af"
```

For detailed troubleshooting, see [GitHub Runners Documentation](./GITHUB_RUNNERS.md#troubleshooting)

## Change History

| Date | Change | Notes |
|------|--------|-------|
| 2026-01-25 | Initial setup | Created VN4 GitHub Actions runner infrastructure with 3 H2Cloud VPS nodes |

## Related Documentation

- **[GitHub Runners Guide](./GITHUB_RUNNERS.md)** - Comprehensive runner documentation
- [Clusters Overview](../../CLUSTERS_OVERVIEW.md)
- [Security Guidelines](../../SECURITY_GUIDELINES.md)
- [GitHub Actions Documentation](https://docs.github.com/en/actions/hosting-your-own-runners)
