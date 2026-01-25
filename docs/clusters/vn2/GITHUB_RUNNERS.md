# VN2 Self-Hosted GitHub Runners

> **Last Updated**: January 2026

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Setup Procedure](#setup-procedure)
- [Pre-installed Software](#pre-installed-software)
- [Usage in Workflows](#usage-in-workflows)
- [Service Management](#service-management)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)

## Overview

The VN2 infrastructure consists of 4 VPS servers converted from a K3s cluster to dedicated GitHub Actions self-hosted runners. Each server runs 2 runner instances, one for each GitHub organization.

### Quick Facts

| Metric | Value |
|--------|-------|
| Total Nodes | 4 |
| Runners per Node | 2 |
| Total Runners | 8 |
| Organizations | murror, canh-nv |
| Runner Version | 2.321.0 |
| Runner User | runner |

## Architecture

### Infrastructure Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                  VN2 Self-Hosted Runner Fleet                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  vps28 (163.61.73.77)                                    │    │
│  │  ├── actions.runner.murror-vn2-murror-1                 │    │
│  │  └── actions.runner.canh-nv-vn2-canh-nv-1               │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  vps29 (163.61.73.78)                                    │    │
│  │  ├── actions.runner.murror-vn2-murror-2                 │    │
│  │  └── actions.runner.canh-nv-vn2-canh-nv-2               │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  vps30 (163.61.73.79)                                    │    │
│  │  ├── actions.runner.murror-vn2-murror-3                 │    │
│  │  └── actions.runner.canh-nv-vn2-canh-nv-3               │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  vps31 (163.61.73.90)                                    │    │
│  │  ├── actions.runner.murror-vn2-murror-4                 │    │
│  │  └── actions.runner.canh-nv-vn2-canh-nv-4               │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Runner Hosts

| Node | External IP | Runners | Labels |
|------|-------------|---------|--------|
| vps28 | 163.61.73.77 | vn2-murror-1, vn2-canh-nv-1 | self-hosted,linux,x64,vn2 |
| vps29 | 163.61.73.78 | vn2-murror-2, vn2-canh-nv-2 | self-hosted,linux,x64,vn2 |
| vps30 | 163.61.73.79 | vn2-murror-3, vn2-canh-nv-3 | self-hosted,linux,x64,vn2 |
| vps31 | 163.61.73.90 | vn2-murror-4, vn2-canh-nv-4 | self-hosted,linux,x64,vn2 |

### Directory Structure

```
/home/runner/
├── runners/
│   ├── murror/           # Runner installation for murror org
│   │   ├── config.sh
│   │   ├── run.sh
│   │   ├── runsvc.sh
│   │   └── .runner       # Runner configuration
│   └── canh-nv/          # Runner installation for canh-nv org
│       ├── config.sh
│       ├── run.sh
│       ├── runsvc.sh
│       └── .runner
└── work/                 # Shared work directory for job execution
```

### Network Configuration

- **Docker MTU**: 1400 (configured for Wireguard compatibility)
- **DNS Servers**: 8.8.8.8, 8.8.4.4
- **Outbound Access**: Required to github.com, ghcr.io, docker.io

## Prerequisites

### GitHub Personal Access Tokens (PATs)

Each organization requires a PAT with permissions to register self-hosted runners.

#### Creating a PAT

1. Go to **GitHub Settings** → **Developer settings** → **Personal access tokens** → **Fine-grained tokens**
2. Click **Generate new token**
3. Configure:
   - **Token name**: `vn2-runners-setup`
   - **Expiration**: Set as needed
   - **Resource owner**: Select the organization (murror or canh-nv)
   - **Repository access**: No repositories needed
   - **Organization permissions**:
     - **Self-hosted runners**: Read and Write
4. Generate and save the token securely

#### Environment Variable Naming

| Organization | Environment Variable |
|--------------|---------------------|
| murror | `GITHUB_MURROR_PAT` |
| canh-nv | `GITHUB_CANH_NV_PAT` |

#### Local PAT Storage

PATs are stored locally in `vn2-runners.secrets` (gitignored):

```bash
# Load PATs before running playbooks
source vn2-runners.secrets
```

### Server Requirements

- **OS**: Ubuntu 24.04 LTS (noble) or Debian-based
- **SSH**: Root access via SSH
- **Resources**: Minimum 2 CPU, 4GB RAM per node
- **Network**: Outbound internet access

### Ansible Control Node

- Ansible 2.9+ installed
- SSH access to all runner hosts
- Clone of k3s-ansible repository

## Setup Procedure

### Step 1: Load PAT Credentials

```bash
cd /Users/canhnv/development/canhnv/k3s-ansible
source vn2-runners.secrets
```

### Step 2: Review Inventory

The inventory file `inventory.vn2-runners.yml` defines:
- Host IPs and SSH credentials
- Runner version and user configuration
- GitHub organizations and labels

### Step 3: Run Setup Playbook

```bash
ansible-playbook playbooks/setup-github-runners.yml -i inventory.vn2-runners.yml
```

### Step 4: Verify Installation

Check runners in GitHub UI:
- **murror**: https://github.com/organizations/murror/settings/actions/runners
- **canh-nv**: https://github.com/organizations/canh-nv/settings/actions/runners

Or verify via SSH:

```bash
ssh root@163.61.73.77 "systemctl status actions.runner.murror-vn2-murror-1"
```

## Pre-installed Software

### System Packages

| Package | Purpose |
|---------|---------|
| curl, wget | HTTP clients |
| git | Version control |
| jq | JSON processing |
| build-essential | C/C++ compiler toolchain |
| libssl-dev, libffi-dev | SSL and FFI libraries |
| python3, python3-pip | Python runtime |
| unzip | Archive extraction |
| postgresql-client | Database CLI tools |

### Docker

| Component | Description |
|-----------|-------------|
| docker-ce | Docker Engine |
| docker-ce-cli | Docker CLI |
| containerd.io | Container runtime |
| docker-buildx-plugin | Multi-platform builds |
| docker-compose-plugin | Compose V2 |

**Configuration** (`/etc/docker/daemon.json`):
```json
{
  "mtu": 1400,
  "dns": ["8.8.8.8", "8.8.4.4"],
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

### Development Tools

| Tool | Version | Installation |
|------|---------|--------------|
| Node.js | 22 LTS | NodeSource repository |
| pnpm | Latest | npm global package |
| kubectl | Latest stable | Official binary |
| Helm | v3 | Official script |

### Verify Installed Versions

```bash
ssh root@163.61.73.77 << 'EOF'
echo "Docker: $(docker --version)"
echo "Node.js: $(node --version)"
echo "pnpm: $(pnpm --version)"
echo "kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
echo "Helm: $(helm version --short)"
EOF
```

## Usage in Workflows

### Basic Workflow

```yaml
name: Build and Test
on: [push, pull_request]

jobs:
  build:
    runs-on: [self-hosted, linux, x64, vn2, murror]
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        run: |
          node --version
          pnpm --version

      - name: Install dependencies
        run: pnpm install

      - name: Build
        run: pnpm build

      - name: Test
        run: pnpm test
```

### Docker Build Workflow

```yaml
name: Docker Build
on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: [self-hosted, linux, x64, vn2, murror]
    steps:
      - uses: actions/checkout@v4

      - name: Login to GHCR
        run: echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin

      - name: Build and Push
        run: |
          docker build -t ghcr.io/${{ github.repository }}:${{ github.sha }} .
          docker push ghcr.io/${{ github.repository }}:${{ github.sha }}
```

### Kubernetes Deployment

```yaml
name: Deploy to K8s
on:
  workflow_dispatch:

jobs:
  deploy:
    runs-on: [self-hosted, linux, x64, vn2, murror]
    steps:
      - uses: actions/checkout@v4

      - name: Setup kubeconfig
        run: echo "${{ secrets.KUBECONFIG }}" | base64 -d > ~/.kube/config

      - name: Deploy with Helm
        run: |
          helm upgrade --install myapp ./helm \
            --namespace production \
            --set image.tag=${{ github.sha }}
```

### Matrix Strategy (Parallel Jobs)

```yaml
name: Matrix Build
on: [push]

jobs:
  build:
    runs-on: [self-hosted, linux, x64, vn2, murror]
    strategy:
      matrix:
        node: [18, 20, 22]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
      - run: npm test
```

### Label Reference

| Label | Description | Use Case |
|-------|-------------|----------|
| self-hosted | Self-hosted runner | Required |
| linux | Linux OS | Required |
| x64 | AMD64 architecture | Required |
| vn2 | VN2 runner pool | Pool selection |
| murror | murror organization | Org-specific jobs |
| canh-nv | canh-nv organization | Org-specific jobs |

## Service Management

### Check Status

```bash
# All runner services on a node
ssh root@163.61.73.77 "systemctl status 'actions.runner.*'"

# Specific runner
ssh root@163.61.73.77 "systemctl status actions.runner.murror-vn2-murror-1"
```

### Start/Stop/Restart

```bash
# Restart a runner
ssh root@163.61.73.77 "systemctl restart actions.runner.murror-vn2-murror-1"

# Stop a runner (for maintenance)
ssh root@163.61.73.77 "systemctl stop actions.runner.murror-vn2-murror-1"

# Start a runner
ssh root@163.61.73.77 "systemctl start actions.runner.murror-vn2-murror-1"
```

### View Logs

```bash
# Follow logs in real-time
ssh root@163.61.73.77 "journalctl -u actions.runner.murror-vn2-murror-1 -f"

# Last 100 lines
ssh root@163.61.73.77 "journalctl -u actions.runner.murror-vn2-murror-1 -n 100"

# Logs since specific time
ssh root@163.61.73.77 "journalctl -u actions.runner.murror-vn2-murror-1 --since '1 hour ago'"
```

### Check All Nodes

```bash
for ip in 163.61.73.77 163.61.73.78 163.61.73.79 163.61.73.90; do
  echo "=== $ip ==="
  ssh root@$ip "systemctl status 'actions.runner.*' --no-pager | grep -E '(\.service|Active:)'"
done
```

## Maintenance

### Update Runner Version

1. Update version in inventory:
   ```yaml
   # inventory.vn2-runners.yml
   runner_version: "2.322.0"  # New version
   ```

2. Run playbook with force reconfigure:
   ```bash
   source vn2-runners.secrets
   ansible-playbook playbooks/setup-github-runners.yml \
     -i inventory.vn2-runners.yml \
     -e "force_reconfigure=true"
   ```

### Update System Packages

```bash
# On each node
ssh root@163.61.73.77 "apt update && apt upgrade -y"
```

### Clean Docker Resources

```bash
# Remove unused images, containers, networks
ssh root@163.61.73.77 "docker system prune -af"
```

### Add a New Node

1. Add host to `inventory.vn2-runners.yml`:
   ```yaml
   vps32:
     ansible_host: x.x.x.x
     ansible_user: root
     ansible_ssh_pass: "password"
     runner_name_suffix: "5"
   ```

2. Run playbook:
   ```bash
   source vn2-runners.secrets
   ansible-playbook playbooks/setup-github-runners.yml \
     -i inventory.vn2-runners.yml \
     --limit vps32
   ```

### Remove a Node

1. Unregister runners:
   ```bash
   source vn2-runners.secrets
   ansible-playbook playbooks/unregister-github-runners.yml \
     -i inventory.vn2-runners.yml \
     --limit vps28
   ```

2. Remove from inventory file

## Troubleshooting

### Runner Shows Offline

**Symptoms**: Runner appears offline in GitHub UI

**Diagnosis**:
```bash
ssh root@163.61.73.77 "systemctl status actions.runner.murror-vn2-murror-1"
```

**Solutions**:
1. Restart the service:
   ```bash
   ssh root@163.61.73.77 "systemctl restart actions.runner.murror-vn2-murror-1"
   ```
2. Check network connectivity:
   ```bash
   ssh root@163.61.73.77 "curl -I https://github.com"
   ```

### Jobs Stuck in Queue

**Symptoms**: Jobs pending, not picked up by runners

**Diagnosis**:
- Check runner labels match workflow `runs-on`
- Verify runner is online and idle

**Solutions**:
1. Verify labels in workflow match runner labels
2. Check if all runners are busy with other jobs
3. Restart idle runners

### Docker Permission Denied

**Symptoms**: `permission denied while trying to connect to Docker daemon`

**Solution**:
```bash
# Ensure runner user is in docker group
ssh root@163.61.73.77 "usermod -aG docker runner && systemctl restart actions.runner.murror-vn2-murror-1"
```

### Docker Network Issues

**Symptoms**: Container cannot reach external services

**Diagnosis**:
```bash
ssh root@163.61.73.77 "docker run --rm alpine ping -c 3 8.8.8.8"
```

**Solution**: MTU may need adjustment in `/etc/docker/daemon.json`

### Service Won't Start

**Symptoms**: `systemctl start` fails

**Diagnosis**:
```bash
ssh root@163.61.73.77 "journalctl -u actions.runner.murror-vn2-murror-1 -n 50"
```

**Common Issues**:
- Missing `.runner` configuration - re-run setup playbook
- Corrupted runner files - delete and re-extract
- Permission issues - check ownership of runner directory

### Disk Space Full

**Symptoms**: Jobs fail with disk space errors

**Solution**:
```bash
# Clean Docker
ssh root@163.61.73.77 "docker system prune -af"

# Clean old job directories
ssh root@163.61.73.77 "rm -rf /home/runner/work/_temp/*"
```

## Security Considerations

### Private Repositories Only

> **Warning**: Self-hosted runners should only be used with **private repositories**. Public repositories allow anyone to fork and run workflows on your runners, potentially executing malicious code.

### Token Security

- PATs are only used during setup, not stored on runners
- Store PATs in gitignored files (`vn2-runners.secrets`)
- Rotate PATs periodically
- Use fine-grained PATs with minimal permissions

### Runner Isolation

- Runners execute as non-root user (`runner`)
- Docker access is controlled via group membership
- Each organization has separate runner instances
- Work directories are isolated per job

### Network Security

- Runners have outbound-only internet access
- Consider firewall rules to restrict inbound access
- SSH access should be key-based, not password

### Monitoring and Auditing

- Review runner logs periodically
- Monitor for unusual job activity
- Check GitHub audit logs for runner-related events
- Set up alerts for runner offline status

## Related Documentation

- [VN2 Cluster Overview](./README.md)
- [Infrastructure Guide](../../INFRASTRUCTURE.md)
- [Security Guidelines](../../SECURITY_GUIDELINES.md)
- [GitHub Actions Documentation](https://docs.github.com/en/actions/hosting-your-own-runners)

## Change History

| Date | Change | Author |
|------|--------|--------|
| 2026-01 | Initial documentation for self-hosted runners | - |
| 2026-01 | Converted from K3s cluster to dedicated runners | - |
