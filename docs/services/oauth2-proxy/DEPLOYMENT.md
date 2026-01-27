# oauth2-proxy Deployment Guide

## Prerequisites

| Component | Version | Purpose |
|-----------|---------|---------|
| Kubernetes | 1.24+ | K3s cluster |
| Helm | 3.x | Package management |
| Traefik | 2.x+ | Ingress with ForwardAuth |
| cert-manager | 1.x | TLS certificates |

## OAuth Provider Setup

### Google OAuth

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create OAuth 2.0 credentials (Web application)
3. Set redirect URI: `https://oauth2-proxy.<cluster>.canhnv.com/oauth2/callback`
4. Note Client ID and Client Secret

### GitHub OAuth

1. Go to [GitHub Developer Settings](https://github.com/settings/developers)
2. Create new OAuth App
3. Set callback URL: `https://oauth2-proxy.<cluster>.canhnv.com/oauth2/callback`

## Deployment Steps

### 1. Create Secrets

```bash
cd apps/oauth2-proxy/scripts
./create-secrets.sh <cluster>
```

### 2. Deploy

```bash
./deploy.sh <cluster>
```

### 3. Verify

```bash
kubectl get pods -n oauth2-proxy
curl -I https://oauth2-proxy.<cluster>.canhnv.com/ping
```

## Deploying to Other Clusters

1. Create cluster directory:
   ```bash
   mkdir -p apps/oauth2-proxy/clusters/<cluster>
   ```

2. Copy and customize files:
   ```bash
   cp apps/oauth2-proxy/clusters/sg3/*.yaml apps/oauth2-proxy/clusters/<cluster>/
   # Update cluster name, domains in files
   ```

3. Create secrets and deploy:
   ```bash
   ./scripts/create-secrets.sh <cluster>
   ./scripts/deploy.sh <cluster>
   ```

## Upgrading

Update image tag in `base/values-base.yaml`, then:

```bash
./scripts/deploy.sh <cluster>
```

## Uninstalling

```bash
helm uninstall oauth2-proxy -n oauth2-proxy
kubectl delete namespace oauth2-proxy
```
