# Custom GitHub Actions Runner Image for Murror
# Based on the official ARC runner image with additional tools
#
# Build:
#   docker build -t ghcr.io/murror/arc-runner:latest .
#
# Push:
#   docker push ghcr.io/murror/arc-runner:latest

ARG RUNNER_VERSION=2.321.0
FROM ghcr.io/actions/actions-runner:${RUNNER_VERSION}

# Switch to root for installations
USER root

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

# Switch back to runner user
USER runner

# Set working directory
WORKDIR /home/runner

# Labels for identification
LABEL org.opencontainers.image.title="Murror ARC Runner"
LABEL org.opencontainers.image.description="Custom GitHub Actions Runner for Murror CI/CD"
LABEL org.opencontainers.image.source="https://github.com/murror/k3s-ansible"
