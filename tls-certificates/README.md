# TLS Certificates Management for K3s Clusters

This directory contains automated TLS certificate management using cert-manager with Cloudflare DNS-01 challenge for all K3s clusters.

## Overview

Cert-manager automatically provisions and manages TLS certificates from Let's Encrypt using DNS-01 challenge via Cloudflare API. This allows wildcard certificates and certificates for domains behind firewalls.

## Directory Structure

```
tls-certificates/
├── README.md                    # This file
├── .gitignore                   # Protect secrets from git
│
├── secrets/                     ***REMOVED***s (gitignored)
│   ├── cloudflare-secret.yaml               # Template for xbuzi.com (placeholder)
│   ├── cloudflare-secret.local.yaml         # xbuzi.com token (gitignored)
│   ├── canhnv-com-secret.local.yaml         # canhnv.com token (gitignored)
│   └── murror-cloudflare-secret.yaml        # murror.app token (gitignored)
│
├── issuers/                     # ClusterIssuer definitions by domain
│   ├── canhnv-com-clusterissuer.yaml        # canhnv.com staging & prod
│   ├── xbuzi-com-clusterissuer.yaml         # xbuzi.com staging & prod
│   └── ambercare-app-clusterissuer.yaml     # murror.app staging & prod
│
├── examples/                    # Example Certificate resources
│   ├── certificate-examples.yaml            # General usage examples
│   └── debug-certificate.yaml               # Debug/test certificate
│
├── deployments/                 # Fleet-wide deployment automation
│   ├── deploy-all-issuers.sh                # Deploy all issuers to all clusters
│   ├── deploy-canhnv-com.sh                 # Deploy canhnv.com issuer
│   ├── deploy-xbuzi-com.sh                  # Deploy xbuzi.com issuer
│   └── deploy-ambercare-app.sh              # Deploy ambercare-app issuer
│
└── clusters/                    # Cluster-specific scripts
    ├── dev/
    │   ├── install-cert-manager.sh          # Install cert-manager
    │   └── install-issuers.sh               # Install all issuers
    ├── eu/
    ├── us/
    ├── vn/
    └── [other clusters...]
```

## Supported Domains

### 1. canhnv.com
- **ClusterIssuers**: `canhnv-com-staging`, `canhnv-com-prod`
- **Email**: canhcvp1998@gmail.com
- **Challenge**: DNS-01 (Cloudflare)
- **Secret**: `cloudflare-token-secret`

### 2. xbuzi.com
- **ClusterIssuers**: `xbuzi-com-staging`, `xbuzi-com`
- **Email**: canhcvp1998@gmail.com
- **Challenge**: DNS-01 (Cloudflare)
- **Secret**: `cloudflare-token-secret`
- **DNS Zone Selector**: `xbuzi.com`

### 3. murror.app (ambercare-app)
- **ClusterIssuers**: `ambercare-app-staging`, `ambercare-app`
- **Email**: canh@murror.app
- **Challenge**: DNS-01 (Cloudflare)
- **Secret**: `murror-cloudflare-token-secret`

## Quick Start

### 1. Deploy to All Clusters

Deploy all ClusterIssuers to all clusters:

```bash
./deployments/deploy-all-issuers.sh
```

Or deploy a specific domain:

```bash
./deployments/deploy-canhnv-com.sh
./deployments/deploy-xbuzi-com.sh
./deployments/deploy-ambercare-app.sh
```

### 2. Deploy to a Specific Cluster

For US cluster:

```bash
# Install cert-manager (if not already installed)
./clusters/us/install-cert-manager.sh

# Install all ClusterIssuers
./clusters/us/install-issuers.sh
```

## Usage in Kubernetes

### Staging (for testing)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-staging
  annotations:
    cert-manager.io/cluster-issuer: "canhnv-com-staging"    # canhnv.com
    # OR
    cert-manager.io/cluster-issuer: "xbuzi-com-staging"     # xbuzi.com
    # OR
    cert-manager.io/cluster-issuer: "ambercare-app-staging" # murror.app
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - my-app.canhnv.com
    secretName: my-app-staging-tls
  rules:
  - host: my-app.canhnv.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
```

### Production

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: "canhnv-com-prod"   # canhnv.com
    # OR
    cert-manager.io/cluster-issuer: "xbuzi-com"         # xbuzi.com
    # OR
    cert-manager.io/cluster-issuer: "ambercare-app"     # murror.app
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - api.canhnv.com
    secretName: my-app-tls
  rules:
  - host: api.canhnv.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
```

### Wildcard Certificate Example

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-canhnv-com
  namespace: default
spec:
  secretName: wildcard-canhnv-com-tls
  issuerRef:
    name: canhnv-com-prod
    kind: ClusterIssuer
  commonName: "*.canhnv.com"
  dnsNames:
    - "canhnv.com"
    - "*.canhnv.com"
```

## Verification

### Check ClusterIssuers

```bash
kubectl get clusterissuer
kubectl describe clusterissuer canhnv-com-prod
```

### Check Certificates

```bash
kubectl get certificate -A
kubectl describe certificate <cert-name> -n <namespace>
```

### Check Secrets

```bash
kubectl get secret -n cert-manager
kubectl get secret <tls-secret-name> -n <namespace>
```

## Troubleshooting

### Certificate Not Ready

1. Check certificate status:
   ```bash
   kubectl describe certificate <cert-name> -n <namespace>
   ```

2. Check certificate request:
   ```bash
   kubectl get certificaterequest -n <namespace>
   kubectl describe certificaterequest <request-name> -n <namespace>
   ```

3. Check cert-manager logs:
   ```bash
   kubectl logs -n cert-manager deploy/cert-manager -f
   ```

### Common Issues

1. **DNS Challenge Failed**:
   - Verify Cloudflare API token has DNS edit permissions
   - Check DNS zone is correctly configured
   - Verify domain ownership in Cloudflare

2. **Rate Limits**:
   - Use staging issuers for testing
   - Let's Encrypt has rate limits per domain
   - Wait before retrying failed certificates

3. **Webhook Errors**:
   - Ensure cert-manager webhook is running
   - Check webhook service and endpoints
   - Verify network policies allow webhook traffic

4. **Secret Not Found**:
   - Verify secret exists: `kubectl get secret -n cert-manager`
   - Check secret name matches ClusterIssuer configuration
   - Ensure secret is in cert-manager namespace

## Security

- **Secrets Protection**: All `*.local.yaml` files are gitignored to prevent exposing API tokens
- **Token Permissions**: Cloudflare API tokens should have minimal permissions (Zone:DNS:Edit)
- **Secret Rotation**: Rotate Cloudflare API tokens periodically
- **Namespace Isolation**: Secrets are stored in cert-manager namespace

## Maintenance

### Update Cloudflare API Token

1. Generate new token in Cloudflare dashboard
2. Update the appropriate secret file in `secrets/`
3. Redeploy to affected clusters:
   ```bash
   kubectl apply -f secrets/<secret-file>.yaml
   ```

### Upgrade cert-manager

```bash
helm upgrade cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version <new-version> \
  --set crds.enabled=true
```

### Add New Domain

1. Create secret file in `secrets/`
2. Create ClusterIssuer file in `issuers/`
3. Create deployment script in `deployments/`
4. Update this README
5. Deploy to clusters

## Support

For issues with:
- **cert-manager**: Check [cert-manager documentation](https://cert-manager.io/docs/)
- **Cloudflare API**: Verify API token permissions
- **Let's Encrypt**: Check rate limits and DNS propagation
- **Cluster access**: Verify kubeconfig and cluster connectivity
