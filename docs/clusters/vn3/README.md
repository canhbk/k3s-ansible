# VN3 Infrastructure (Vietnam Tertiary)

## Overview

> **Important**: VN3 is a dedicated GitHub Actions self-hosted runner infrastructure.

The VN3 infrastructure consists of 4 VPS servers (vps5, vps18, vps17, vps12) that serve as dedicated GitHub Actions self-hosted runners for CI/CD workflows.

**Last Updated**: 2026-01-25

## Infrastructure Information

- **Type**: GitHub Actions Self-Hosted Runners
- **Environment**: Production CI/CD
- **Region**: Vietnam (vn3)
- **Organizations**: murror, canh-nv
- **Total Runners**: 8 (2 per node)

## Runner Infrastructure

### Runner Nodes (4)

| Hostname | External IP | Runners | Status |
|----------|-------------|---------|--------|
| vps5-h2cloud-vn | 180.93.98.54 | vn3-murror-1, vn3-canh-nv-1 | Active |
| vps18-h2cloud-vn | 180.93.98.101 | vn3-murror-2, vn3-canh-nv-2 | Active |
| vps17-h2cloud-vn | 180.93.98.15 | vn3-murror-3, vn3-canh-nv-3 | Active |
| vps12-h2cloud-vn | 180.93.98.10 | vn3-murror-4, vn3-canh-nv-4 | Active |

Each node runs two runner instances: one for the **murror** organization and one for the **canh-nv** organization.

## Network Configuration

- **Outbound Access**: GitHub.com, GHCR.io, Docker Hub
- **Docker MTU**: 1400 (Wireguard optimized)
- **DNS**: 8.8.8.8, 8.8.4.4

## Deployment Method

The GitHub runners were deployed using Ansible playbooks.

See: `playbooks/setup-github-runners.yml` and `inventory.vn3-runners.yml`

### Setup Commands

```bash
# Load PAT credentials
source vn3-runners.secrets

# Deploy runners to all nodes
ansible-playbook playbooks/setup-github-runners.yml -i inventory.vn3-runners.yml
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
    runs-on: [self-hosted, linux, x64, vn3, murror]
    steps:
      - uses: actions/checkout@v4
      - run: pnpm install && pnpm build
```

### For canh-nv Organization

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, x64, vn3, canh-nv]
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
ssh root@180.93.98.54 "systemctl status 'actions.runner.*'"

# View runner logs
ssh root@180.93.98.54 "journalctl -u actions.runner.murror-vn3-murror-1 -f"
```

### GitHub UI

View runners in GitHub organization settings:
- **murror**: https://github.com/organizations/murror/settings/actions/runners
- **canh-nv**: https://github.com/organizations/canh-nv/settings/actions/runners

## Common Operations

### Check Runner Status

```bash
# Check all runners on all nodes
for ip in 180.93.98.54 180.93.98.101 180.93.98.15 180.93.98.10; do
  echo "=== $ip ==="
  ssh root@$ip "systemctl status 'actions.runner.*' --no-pager | grep -E '(\.service|Active:)'"
done
```

### Restart a Runner

```bash
ssh root@180.93.98.54 "systemctl restart actions.runner.murror-vn3-murror-1"
```

### Update Runner Version

```bash
# Load credentials
source vn3-runners.secrets

# Update and redeploy
ansible-playbook playbooks/setup-github-runners.yml \
  -i inventory.vn3-runners.yml \
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
ssh root@180.93.98.54 "systemctl status docker"

# Test Docker
ssh root@180.93.98.54 "docker run --rm hello-world"

# Clean up disk space
ssh root@180.93.98.54 "docker system prune -af"
```

For detailed troubleshooting, see [GitHub Runners Documentation](./GITHUB_RUNNERS.md#troubleshooting)

## Change History

| Date | Change | Notes |
|------|--------|-------|
| 2026-01-25 | Initial setup of VN3 runners | Deployed 4 nodes with 8 total runners for murror and canh-nv organizations |

## Related Documentation

- **[GitHub Runners Guide](./GITHUB_RUNNERS.md)** - Comprehensive runner documentation
- [Clusters Overview](../../CLUSTERS_OVERVIEW.md)
- [Security Guidelines](../../SECURITY_GUIDELINES.md)
- [GitHub Actions Documentation](https://docs.github.com/en/actions/hosting-your-own-runners)
