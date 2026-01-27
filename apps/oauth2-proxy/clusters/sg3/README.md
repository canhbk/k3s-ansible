# oauth2-proxy - SG3 Cluster

oauth2-proxy deployment for the SG3 (Singapore OVH) production cluster.

## Cluster Information

| Property | Value |
|----------|-------|
| Cluster | sg3 |
| Provider | OVH |
| Region | Singapore |
| Environment | Production |
| Replicas | 2 |

## Domains

- **oauth2-proxy**: https://oauth2-proxy.sg3.canhnv.com
- **OAuth Callback**: https://oauth2-proxy.sg3.canhnv.com/oauth2/callback

## Prerequisites

1. cert-manager with `canhnv-com-prod` ClusterIssuer
2. Traefik ingress controller
3. kube-prometheus-stack (for ServiceMonitor)
4. Google OAuth credentials

## Secrets Setup

```bash
cd apps/oauth2-proxy/scripts
./create-secrets.sh sg3
```

Or manually:

```bash
COOKIE_SECRET=$(openssl rand -base64 32 | head -c 32 | base64)

kubectl create secret generic oauth2-proxy-secrets \
  --namespace oauth2-proxy \
  --from-literal=client-id="YOUR_GOOGLE_CLIENT_ID" \
  --from-literal=client-secret="YOUR_GOOGLE_CLIENT_SECRET" \
  --from-literal=cookie-secret="$COOKIE_SECRET"
```

## Deployment

```bash
cd apps/oauth2-proxy
./scripts/deploy.sh sg3
```

## Protect a Service

Add this annotation to your Ingress:

```yaml
annotations:
  traefik.ingress.kubernetes.io/router.middlewares: oauth2-proxy-oauth2-proxy-chain@kubernetescrd
```

## Verification

```bash
# Check pods
kubectl get pods -n oauth2-proxy

# Check service
kubectl get svc -n oauth2-proxy

# Test health
curl -I https://oauth2-proxy.sg3.canhnv.com/ping
```

## Files

| File | Purpose |
|------|---------|
| values.yaml | SG3-specific Helm values |
| ingress.yaml | Ingress and Certificate |
| middleware-forwardauth.yaml | Traefik ForwardAuth middleware |
| servicemonitor.yaml | Prometheus ServiceMonitor |
