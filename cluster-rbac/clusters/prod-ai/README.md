# Production AI Team - Log Reader Access

This directory contains RBAC configuration for providing the AI team with log reader access to the production AI namespace.

## Overview

The `ai-team-logger` ServiceAccount provides read-only access to logs in the `nsp-prod-murror-ai` namespace for the production environment.

## Components

- **ai-team-logger-secret.yaml**: ServiceAccount and token secret in the `dev-access` namespace
- **dev-logger-role.yaml**: Role defining log reader permissions (hardcoded to `nsp-prod-murror-ai`)
- **role-binding.yaml**: RoleBinding connecting the ServiceAccount to the Role
- **generate-kubeconfig.sh**: Script to generate the kubeconfig file

## Permissions Granted

Read-only access to the `nsp-prod-murror-ai` namespace:
- Pods and pod logs
- Events

## Setup Instructions

1. Apply the RBAC resources:
```bash
kubectl apply -f ai-team-logger-secret.yaml
kubectl apply -f dev-logger-role.yaml -n nsp-prod-murror-ai
kubectl apply -f role-binding.yaml -n nsp-prod-murror-ai
```

2. Generate the kubeconfig:
```bash
chmod +x generate-kubeconfig.sh
./generate-kubeconfig.sh
```

## Usage

```bash
# Use the generated kubeconfig
kubectl --kubeconfig=ai-prod-log-reader.kubeconfig.yaml get pods -n nsp-prod-murror-ai
kubectl --kubeconfig=ai-prod-log-reader.kubeconfig.yaml logs -n nsp-prod-murror-ai <pod-name>
```

## Security Notes

- This configuration provides access only to the `nsp-prod-murror-ai` namespace
- The kubeconfig contains a token that should be kept secure
- Never commit kubeconfig files to version control

## Note

The ServiceAccount is currently in the `dev-access` namespace. Consider moving it to a more appropriate namespace like `prod-access` for production environments.
