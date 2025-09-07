# Cert-Manager Configuration for K3s Clusters

This directory contains cert-manager installation scripts and configurations for each K3s cluster.

## Overview

Cert-manager is used to automatically provision and manage TLS certificates from Let's Encrypt for ingress resources.

## Directory Structure

```
cert-manager/
├── base/                    # Base configurations shared across clusters
│   ├── cloudflare-secret.yaml      ***REMOVED*** secret
│   └── xbuzi-com-clusterissuer.yaml # xbuzi.com ClusterIssuers
├── clusters/               # Cluster-specific configurations
│   ├── dev/               # Dev cluster configuration
│   ├── eu/                # EU cluster configuration
│   ├── jp/                # JP cluster configuration
│   ├── sg/                # SG cluster configuration
│   ├── sg2/               # SG2 cluster configuration
│   ├── us/                # US cluster configuration
│   ├── vn/                # VN cluster configuration
│   └── vn2/               # VN2 cluster configuration
└── deploy-xbuzi-clusterissuer.sh   # Deploy xbuzi.com to all clusters
```

## Installation

To install cert-manager on a specific cluster:

```bash
# For US cluster
./clusters/us/install.sh

# For other clusters
./clusters/<cluster-name>/install.sh
```

## Components Installed

1. **Cert-Manager**: v1.18.2
   - Webhook
   - Controller
   - CAInjector

2. **ClusterIssuers**:
   - `canhnv-com-staging`: Let's Encrypt staging (HTTP-01 challenge)
   - `canhnv-com-prod`: Let's Encrypt production (HTTP-01 challenge)
   - `xbuzi-com-staging`: Let's Encrypt staging (DNS-01 challenge with Cloudflare)
   - `xbuzi-com`: Let's Encrypt production (DNS-01 challenge with Cloudflare)

## Usage

To use cert-manager with your ingress resources, add these annotations:

### For Staging (Testing)

```yaml
annotations:
  cert-manager.io/cluster-issuer: "canhnv-com-staging"
```

### For Production

```yaml
annotations:
  cert-manager.io/cluster-issuer: "canhnv-com-prod"  # For HTTP-01 challenge
  # OR
  cert-manager.io/cluster-issuer: "xbuzi-com"        # For DNS-01 challenge (xbuzi.com domain)
```

## Example Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: "canhnv-com-prod"
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - my-app.us.k3s.canhnv.com
    secretName: my-app-tls
  rules:
  - host: my-app.us.k3s.canhnv.com
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

## Verification

Check cert-manager pods:

```bash
kubectl get pods -n cert-manager
```

Check ClusterIssuers:

```bash
kubectl get clusterissuer
```

Check certificates in a namespace:

```bash
kubectl get certificate -n <namespace>
```

## Troubleshooting

### Certificate Not Ready

Check certificate status:

```bash
kubectl describe certificate <cert-name> -n <namespace>
```

Check certificate request:

```bash
kubectl get certificaterequest -n <namespace>
```

Check cert-manager logs:

```bash
kubectl logs -n cert-manager deploy/cert-manager
```

### Common Issues

1. **DNS Challenge Failed**: Ensure your domain DNS is properly configured
2. **Rate Limits**: Use staging issuer for testing to avoid Let's Encrypt rate limits
3. **Webhook Errors**: Ensure cert-manager webhook is running and accessible

## xbuzi.com Domain Support

### Prerequisites

1. Configure your Cloudflare API token in `/cert-manager/base/cloudflare-secret.yaml`
2. Ensure cert-manager is installed on the target cluster

### Deploying xbuzi.com ClusterIssuers

Deploy to all clusters at once:

```bash
./cert-manager/deploy-xbuzi-clusterissuer.sh
```

Or deploy to a specific cluster:

```bash
./cert-manager/clusters/<cluster-name>/install-xbuzi.sh
```

### Using xbuzi.com Certificates

Example ingress with xbuzi.com domain:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: "xbuzi-com"
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - my-app.xbuzi.com
    secretName: my-app-xbuzi-tls
  rules:
  - host: my-app.xbuzi.com
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

## Maintenance

To upgrade cert-manager:

```bash
helm upgrade cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version <new-version> \
  --set crds.enabled=true
```
