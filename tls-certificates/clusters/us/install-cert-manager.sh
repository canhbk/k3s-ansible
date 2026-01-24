#!/bin/bash

# Install cert-manager for US cluster
set -e

echo "Installing cert-manager for US cluster..."

# Switch to US cluster context
kubectl config use-context us

# Add Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.18.2 \
  --set crds.enabled=true \
  --wait

echo "cert-manager installed successfully!"

# Create ClusterIssuer for Let's Encrypt staging
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: canhnv-com-staging
spec:
  acme:
    email: admin@canhnv.com
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: canhnv-com-staging-issuer-account-key
    solvers:
    - http01:
        ingress:
          class: traefik
EOF

# Create ClusterIssuer for Let's Encrypt production
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: canhnv-com-prod
spec:
  acme:
    email: admin@canhnv.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: canhnv-com-prod-issuer-account-key
    solvers:
    - http01:
        ingress:
          class: traefik
EOF

echo "ClusterIssuers created successfully!"

# Verify installation
kubectl get pods -n cert-manager
kubectl get clusterissuer