# Actions Runner Controller (ARC)

GitHub self-hosted runners on Kubernetes using Actions Runner Controller v2.

## Overview

ARC enables autoscaling GitHub Actions runners on Kubernetes clusters. Runners scale from 0 to N based on workflow demand, providing cost-efficient CI/CD infrastructure.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         GitHub                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              Organization: murror                        │    │
│  │  ┌─────────────────┐  ┌─────────────────────────────┐   │    │
│  │  │   GitHub App    │  │   Workflow Jobs Queue       │   │    │
│  │  │ (arc-runners)   │  │   [job1] [job2] [job3]...   │   │    │
│  │  └────────┬────────┘  └──────────────┬──────────────┘   │    │
│  └───────────│──────────────────────────│──────────────────┘    │
└──────────────│──────────────────────────│───────────────────────┘
               │                          │
               ▼                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    VN2 K3s Cluster                               │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              Namespace: arc-systems                      │    │
│  │  ┌─────────────────────────────────────────────────┐    │    │
│  │  │           ARC Controller                         │    │    │
│  │  │   - Manages runner lifecycle                     │    │    │
│  │  │   - Handles scale up/down                        │    │    │
│  │  └─────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              Namespace: arc-runners                      │    │
│  │                                                          │    │
│  │  ┌───────────────┐     ┌─────────────────────────────┐  │    │
│  │  │   Listener    │────▶│  Runner Pods (0-10)         │  │    │
│  │  │               │     │  ┌───────┐ ┌───────┐        │  │    │
│  │  │  Receives     │     │  │runner │ │ dind  │        │  │    │
│  │  │  webhook      │     │  │       │ │       │        │  │    │
│  │  │  events       │     │  └───────┘ └───────┘        │  │    │
│  │  └───────────────┘     └─────────────────────────────┘  │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
arc/
├── README.md                           # This file
├── base/
│   ├── namespace.yaml                  # Namespace definitions
│   └── secrets-template.yaml           # Secret templates (DO NOT COMMIT REAL VALUES)
├── clusters/
│   └── vn2/
│       ├── values-controller.yaml      # ARC controller Helm values
│       ├── values-runner-scaleset.yaml # Runner scale set Helm values
│       └── custom-runner-image/
│           └── Dockerfile              # Custom runner image with tools
└── scripts/
    ├── install-arc.sh                  # Installation script
    └── verify-arc.sh                   # Verification script
```

## Prerequisites

### 1. GitHub App

Create a GitHub App for runner authentication:

1. Go to: https://github.com/organizations/murror/settings/apps/new
2. Set App Name: `arc-runners-vn2`
3. Disable Webhook (not needed)
4. Configure permissions:
   - **Repository**: Actions (Read), Administration (Read & Write), Metadata (Read)
   - **Organization**: Self-hosted runners (Read & Write)
5. Install the app on your organization
6. Download the private key (.pem file)
7. Note the App ID and Installation ID

### 2. Kubernetes Secret

Create the GitHub App secret in the cluster:

```bash
kubectl config use-context vn2

kubectl create namespace arc-runners

kubectl create secret generic github-app-secret \
  --namespace arc-runners \
  --from-literal=github_app_id=<APP_ID> \
  --from-literal=github_app_installation_id=<INSTALLATION_ID> \
  --from-file=github_app_private_key=/path/to/private-key.pem
```

## Installation

### Quick Install

```bash
# Ensure you have the GitHub App secret created first
./arc/scripts/install-arc.sh
```

### Manual Install

```bash
# Switch to VN2 cluster
kubectl config use-context vn2

# Create namespaces
kubectl apply -f arc/base/namespace.yaml

# Install ARC Controller
helm upgrade --install arc-controller \
  --namespace arc-systems \
  --values arc/clusters/vn2/values-controller.yaml \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  --version 0.10.1

# Install Runner Scale Set
helm upgrade --install vn2-runners \
  --namespace arc-runners \
  --values arc/clusters/vn2/values-runner-scaleset.yaml \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --version 0.10.1
```

## Verification

```bash
# Run verification script
./arc/scripts/verify-arc.sh

# Or manually check
kubectl -n arc-systems get pods
kubectl -n arc-runners get autoscalingrunnerset
kubectl -n arc-runners get pods
```

Check GitHub UI: https://github.com/organizations/murror/settings/actions/runners

## Usage

### In Workflow Files

```yaml
name: Build and Test

on: [push, pull_request]

jobs:
  build:
    # Use VN2 runners specifically
    runs-on: [self-hosted, vn2-runners]

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 22

      - name: Install pnpm
        uses: pnpm/action-setup@v4

      - name: Build
        run: pnpm install && pnpm build
```

### Docker Builds

```yaml
jobs:
  docker:
    runs-on: [self-hosted, vn2-runners]

    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ghcr.io/murror/my-app:latest
```

## Custom Runner Image

The custom runner image includes:
- Node.js 22 LTS (system-wide)
- pnpm (latest)
- Docker CLI + Buildx
- kubectl
- Helm
- PostgreSQL client
- Pre-cached Node.js versions for faster `actions/setup-node`

### Tool Cache for Faster Builds

The custom runner image pre-caches multiple Node.js versions to eliminate download time during `actions/setup-node` execution. This significantly speeds up workflow runs.

**Pre-cached Node.js versions:**
- Node.js 24.13.0
- Node.js 22.13.0
- Node.js 20.19.0

**How it works:**
1. Node.js binaries are downloaded during image build
2. Extracted to `$RUNNER_TOOL_CACHE/node/{version}/x64/`
3. Marker files (`.complete`) indicate successful cache
4. `actions/setup-node` detects cached versions and skips download

**Benefits:**
- Workflow runs start 30-60 seconds faster
- Reduced network dependency
- Consistent Node.js versions across builds

**Verification:**
```bash
# SSH into a runner pod
kubectl -n arc-runners exec -it <runner-pod> -- bash

# Check cached versions
ls -la /home/runner/actions-tool-cache/node/
# Should show: 24.13.0/ 22.13.0/ 20.19.0/

# Verify tool cache structure
ls -la /home/runner/actions-tool-cache/node/24.13.0/
# Should show: x64/ and x64.complete
```

**Updating cached versions:**

Option 1 - GitHub Actions (Recommended):
```bash
# Trigger workflow manually with custom versions
# Go to: Actions > Build ARC Runner Image > Run workflow
# Or wait for weekly automatic build (Sunday 6 AM UTC)
```

Option 2 - Manual build:
```bash
cd arc/clusters/vn2/custom-runner-image

docker build \
  --build-arg NODE_24_VERSION=24.14.0 \
  --build-arg NODE_22_VERSION=22.14.0 \
  --build-arg NODE_20_VERSION=20.20.0 \
  -t ghcr.io/murror/arc-runner:latest .

docker push ghcr.io/murror/arc-runner:latest

# Restart runner scale set to use new image
helm upgrade vn2-runners \
  --namespace arc-runners \
  --values arc/clusters/vn2/values-runner-scaleset.yaml \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --version 0.13.1
```

### Build Custom Image

```bash
cd arc/clusters/vn2/custom-runner-image

docker build -t ghcr.io/murror/arc-runner:latest .
docker push ghcr.io/murror/arc-runner:latest
```

The custom image is already configured in `values-runner-scaleset.yaml`:
```yaml
containers:
  - name: runner
    image: ghcr.io/murror/arc-runner:latest
    env:
      - name: RUNNER_TOOL_CACHE
        value: "/home/runner/actions-tool-cache"
```

## Troubleshooting

### Runners Not Appearing in GitHub

1. Check listener pod logs:
   ```bash
   kubectl -n arc-runners logs -l app.kubernetes.io/component=runner-scale-set-listener -f
   ```

2. Verify GitHub App credentials:
   ```bash
   kubectl -n arc-runners get secret github-app-secret -o yaml
   ```

### Docker Build Fails

1. Check DinD sidecar is running:
   ```bash
   kubectl -n arc-runners logs <runner-pod> -c dind
   ```

2. Verify DOCKER_HOST environment variable is set correctly

### Network Connectivity Issues in Docker Builds

**Symptoms:**
- TLS handshake failures when pulling from registries
- Connection timeouts to external services
- `corepack` or `pnpm` network errors
- Error: "read: connection reset by peer"

**Root Cause:**
MTU mismatch between the host network and Docker's bridge network. The VN2 cluster uses Wireguard VPN (MTU 1420), but Docker defaults to MTU 1500. This causes packet fragmentation that breaks TLS connections.

**Solution:**
Configure Docker to use MTU 1400 (already configured in VN2 runner scale set):

1. Verify the `docker-daemon-config` ConfigMap exists:
   ```bash
   kubectl -n arc-runners get configmap docker-daemon-config
   ```

2. Check that DinD containers are using the correct MTU:
   ```bash
   kubectl -n arc-runners exec -it <runner-pod> -c dind -- docker network inspect bridge | grep -i mtu
   # Should show: "com.docker.network.driver.mtu": "1400"
   ```

3. Verify daemon.json is mounted:
   ```bash
   kubectl -n arc-runners exec -it <runner-pod> -c dind -- cat /etc/docker/daemon.json
   ```

**Key Configuration:**
- DinD container args: `--mtu=1400` and `--default-network-opt=bridge=com.docker.network.driver.mtu=1400`
- Daemon config: `daemon.json` ConfigMap with MTU settings
- Applies to all networks created by Docker

**Verification:**
Test network connectivity inside a build:
```yaml
- name: Test network
  run: |
    docker run --rm alpine ping -c 4 google.com
    docker run --rm alpine wget -O- https://registry.npmjs.org
```

### Runners Scale Slowly

- Consider setting `minRunners: 1` for faster response
- Check controller logs for scaling events

## Uninstall

```bash
# Remove runner scale set
helm uninstall vn2-runners -n arc-runners

# Remove controller
helm uninstall arc-controller -n arc-systems

# Remove namespaces (optional)
kubectl delete namespace arc-runners
kubectl delete namespace arc-systems
```

## References

- [GitHub ARC Documentation](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller)
- [ARC Helm Charts](https://github.com/actions/actions-runner-controller/tree/master/charts)
