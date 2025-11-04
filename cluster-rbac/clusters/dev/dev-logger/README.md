# Dev Logger - Cluster-Wide Log Reader Access

This directory contains RBAC configuration for providing cluster-wide log reader access to the dev cluster.

## Overview

The `dev-logger` ServiceAccount provides read-only access to logs across the entire dev cluster. This is useful for centralized logging, monitoring, and debugging purposes.

## Components

- **dev-logger-secret.yaml**: ServiceAccount and token secret in the `dev-access` namespace
- **cluster-log-reader-role.yaml**: ClusterRole defining cluster-wide log reader permissions
- **cluster-role-binding.yaml**: ClusterRoleBinding connecting the ServiceAccount to the ClusterRole
- **generate-kubeconfig.sh**: Script to generate the kubeconfig file

## Permissions Granted

Cluster-wide read-only access to:
- Pods and pod logs
- Events
- Basic resource information

## Setup Instructions

1. Switch to dev cluster context:
```bash
kubectl config use-context dev
```

2. Create the dev-access namespace (if not exists):
```bash
kubectl create namespace dev-access
```

3. Apply the RBAC resources:
```bash
kubectl apply -f dev-logger-secret.yaml
kubectl apply -f cluster-log-reader-role.yaml
kubectl apply -f cluster-role-binding.yaml
```

4. Generate the kubeconfig:
```bash
chmod +x generate-kubeconfig.sh
./generate-kubeconfig.sh
```

## Usage

```bash
# Use the generated kubeconfig
kubectl --kubeconfig=dev-logger.kubeconfig.yaml get pods -A
kubectl --kubeconfig=dev-logger.kubeconfig.yaml logs -n <namespace> <pod-name>
```

## Security Notes

- This configuration provides **cluster-wide** access to logs
- For namespace-restricted access, see `../mur-developers/`
- The kubeconfig contains a token that should be kept secure
- Never commit kubeconfig files to version control
