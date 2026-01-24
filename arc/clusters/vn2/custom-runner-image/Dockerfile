# Custom GitHub Actions Runner Image for Murror
# Based on the official ARC runner image with additional tools
#
# Build:
#   docker build -t ghcr.io/murror/arc-runner:latest .
#
# Push:
#   docker push ghcr.io/murror/arc-runner:latest

ARG RUNNER_VERSION=2.331.0
ARG NODE_24_VERSION=24.13.0
ARG NODE_22_VERSION=22.13.0
ARG NODE_20_VERSION=20.19.0

FROM ghcr.io/actions/actions-runner:${RUNNER_VERSION}

# Switch to root for installations
USER root

# Set tool cache environment variable
ENV RUNNER_TOOL_CACHE=/home/runner/actions-tool-cache

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials
    build-essential \
    git \
    curl \
    wget \
    unzip \
    jq \
    # Docker CLI (for DinD communication)
    docker.io \
    # Python (for some actions)
    python3 \
    python3-pip \
    # PostgreSQL client (for integration tests)
    postgresql-client \
    # Clean up
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm globally
RUN npm install -g pnpm@latest

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# Install Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Docker Buildx plugin
RUN mkdir -p /usr/local/lib/docker/cli-plugins \
    && curl -Lo /usr/local/lib/docker/cli-plugins/docker-buildx \
       "https://github.com/docker/buildx/releases/download/v0.19.3/buildx-v0.19.3.linux-amd64" \
    && chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx

# Verify installations
RUN node --version && \
    pnpm --version && \
    docker --version && \
    kubectl version --client && \
    helm version --short

# Create runner workspace directory
RUN mkdir -p /home/runner/_work && \
    chown -R runner:runner /home/runner/_work

# Pre-cache Node.js versions for faster setup-node action
ARG NODE_24_VERSION
ARG NODE_22_VERSION
ARG NODE_20_VERSION

RUN mkdir -p ${RUNNER_TOOL_CACHE}/node && \
    # Download and cache Node.js 24
    curl -fsSL https://nodejs.org/dist/v${NODE_24_VERSION}/node-v${NODE_24_VERSION}-linux-x64.tar.gz \
        | tar xz -C ${RUNNER_TOOL_CACHE}/node && \
    mv ${RUNNER_TOOL_CACHE}/node/node-v${NODE_24_VERSION}-linux-x64 ${RUNNER_TOOL_CACHE}/node/${NODE_24_VERSION} && \
    mkdir -p ${RUNNER_TOOL_CACHE}/node/${NODE_24_VERSION}/x64 && \
    mv ${RUNNER_TOOL_CACHE}/node/${NODE_24_VERSION}/* ${RUNNER_TOOL_CACHE}/node/${NODE_24_VERSION}/x64/ 2>/dev/null || true && \
    touch ${RUNNER_TOOL_CACHE}/node/${NODE_24_VERSION}/x64.complete && \
    # Download and cache Node.js 22
    curl -fsSL https://nodejs.org/dist/v${NODE_22_VERSION}/node-v${NODE_22_VERSION}-linux-x64.tar.gz \
        | tar xz -C ${RUNNER_TOOL_CACHE}/node && \
    mv ${RUNNER_TOOL_CACHE}/node/node-v${NODE_22_VERSION}-linux-x64 ${RUNNER_TOOL_CACHE}/node/${NODE_22_VERSION} && \
    mkdir -p ${RUNNER_TOOL_CACHE}/node/${NODE_22_VERSION}/x64 && \
    mv ${RUNNER_TOOL_CACHE}/node/${NODE_22_VERSION}/* ${RUNNER_TOOL_CACHE}/node/${NODE_22_VERSION}/x64/ 2>/dev/null || true && \
    touch ${RUNNER_TOOL_CACHE}/node/${NODE_22_VERSION}/x64.complete && \
    # Download and cache Node.js 20
    curl -fsSL https://nodejs.org/dist/v${NODE_20_VERSION}/node-v${NODE_20_VERSION}-linux-x64.tar.gz \
        | tar xz -C ${RUNNER_TOOL_CACHE}/node && \
    mv ${RUNNER_TOOL_CACHE}/node/node-v${NODE_20_VERSION}-linux-x64 ${RUNNER_TOOL_CACHE}/node/${NODE_20_VERSION} && \
    mkdir -p ${RUNNER_TOOL_CACHE}/node/${NODE_20_VERSION}/x64 && \
    mv ${RUNNER_TOOL_CACHE}/node/${NODE_20_VERSION}/* ${RUNNER_TOOL_CACHE}/node/${NODE_20_VERSION}/x64/ 2>/dev/null || true && \
    touch ${RUNNER_TOOL_CACHE}/node/${NODE_20_VERSION}/x64.complete && \
    # Set proper ownership
    chown -R runner:runner ${RUNNER_TOOL_CACHE}

# Switch back to runner user
USER runner

# Set working directory
WORKDIR /home/runner

# Labels for identification
LABEL org.opencontainers.image.title="Murror ARC Runner"
LABEL org.opencontainers.image.description="Custom GitHub Actions Runner for Murror CI/CD"
LABEL org.opencontainers.image.source="https://github.com/murror/k3s-ansible"
