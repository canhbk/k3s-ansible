# VN2 Infrastructure (Vietnam Secondary)

## Overview

> **Important**: VN2 has been converted from a K3s cluster to a dedicated GitHub Actions self-hosted runner infrastructure.

The VN2 infrastructure consists of 4 VPS servers (vps28-31) that previously formed a K3s cluster and now serve as dedicated GitHub Actions self-hosted runners for CI/CD workflows.

**Last Updated**: 2026-01-25

## Infrastructure Information

- **Type**: GitHub Actions Self-Hosted Runners
- **Previous Type**: K3s Cluster (decommissioned)
- **Environment**: Production CI/CD
- **Region**: Vietnam (vn2)
- **Organizations**: murror, canh-nv
- **Total Runners**: 8 (2 per node)

## Runner Infrastructure

### Runner Nodes (4)

| Hostname | External IP | Runners | Status |
|----------|-------------|---------|--------|
| vps28-bnix | 163.61.73.77 | vn2-murror-1, vn2-canh-nv-1 | Active |
| vps29-bnix | 163.61.73.78 | vn2-murror-2, vn2-canh-nv-2 | Active |
| vps30-bnix | 163.61.73.79 | vn2-murror-3, vn2-canh-nv-3 | Active |
| vps31-bnix | 163.61.73.90 | vn2-murror-4, vn2-canh-nv-4 | Active |

Each node runs two runner instances: one for the **murror** organization and one for the **canh-nv** organization.

## Network Configuration

- **Outbound Access**: GitHub.com, GHCR.io, Docker Hub
- **Docker MTU**: 1400 (Wireguard optimized)
- **DNS**: 8.8.8.8, 8.8.4.4

## Deployment Method

The GitHub runners were deployed using Ansible playbooks.

See: `playbooks/setup-github-runners.yml` and `inventory.vn2-runners.yml`

### Setup Commands

```bash
# Load PAT credentials
source vn2-runners.secrets

# Deploy runners to all nodes
ansible-playbook playbooks/setup-github-runners.yml -i inventory.vn2-runners.yml
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
    runs-on: [self-hosted, linux, x64, vn2, murror]
    steps:
      - uses: actions/checkout@v4
      - run: pnpm install && pnpm build
```

### For canh-nv Organization

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, x64, vn2, canh-nv]
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
ssh root@163.61.73.77 "systemctl status 'actions.runner.*'"

# View runner logs
ssh root@163.61.73.77 "journalctl -u actions.runner.murror-vn2-murror-1 -f"
```

### GitHub UI

View runners in GitHub organization settings:
- **murror**: https://github.com/organizations/murror/settings/actions/runners
- **canh-nv**: https://github.com/organizations/canh-nv/settings/actions/runners

## Common Operations

### Check Runner Status

```bash
# Check all runners on all nodes
for ip in 163.61.73.77 163.61.73.78 163.61.73.79 163.61.73.90; do
  echo "=== $ip ==="
  ssh root@$ip "systemctl status 'actions.runner.*' --no-pager | grep -E '(\.service|Active:)'"
done
```

### Restart a Runner

```bash
ssh root@163.61.73.77 "systemctl restart actions.runner.murror-vn2-murror-1"
```

### Update Runner Version

```bash
# Load credentials
source vn2-runners.secrets

# Update and redeploy
ansible-playbook playbooks/setup-github-runners.yml \
  -i inventory.vn2-runners.yml \
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
ssh root@163.61.73.77 "systemctl status docker"

# Test Docker
ssh root@163.61.73.77 "docker run --rm hello-world"

# Clean up disk space
ssh root@163.61.73.77 "docker system prune -af"
```

For detailed troubleshooting, see [GitHub Runners Documentation](./GITHUB_RUNNERS.md#troubleshooting)

## Change History

| Date | Change | Notes |
|------|--------|-------|
| 2026-01-25 | Converted to GitHub Actions runners | Decommissioned K3s cluster, converted all 4 nodes to self-hosted runners |
| 2025-12-25 | Added Actions Runner Controller (ARC) | GitHub self-hosted runners with auto-scaling |
| 2025-10-21 | Added vps28-bnix as agent node | Previous networking issues resolved, node rejoined cluster |
| 2024-09-24 | Removed vps28-bnix | Due to networking issues |

## Related Documentation

- **[GitHub Runners Guide](./GITHUB_RUNNERS.md)** - Comprehensive runner documentation
- [Clusters Overview](../../CLUSTERS_OVERVIEW.md)
- [Security Guidelines](../../SECURITY_GUIDELINES.md)
- [GitHub Actions Documentation](https://docs.github.com/en/actions/hosting-your-own-runners)
