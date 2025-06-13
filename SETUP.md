# Setup a new K3s cluster

## Setup k3s using k3s ansible

## Setup Rancher UI

```bash
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable

kubectl create namespace cattle-system

helm repo add jetstack https://charts.jetstack.io

helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true

# Create `manifest.yaml.local` from cloudflare--tls/manifests.yaml.example, then run bellow command

kubectl apply -f cloudflare-tls/manifests.yaml.local

helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=vn2.k3s.canhnv.com \
  --set bootstrapPassword=admin \
  --set ingress.tls.source=letsEncrypt \
  --set letsEncrypt.email=canhcvp1998@gmail.com \
  --set letsEncrypt.ingress.class=traefik
```

## Setup Longhorn

### Install prerequisites

```bash
curl -sSfL -o longhornctl https://github.com/longhorn/cli/releases/download/v1.9.0/longhornctl-linux-amd64
chmod +x longhornctl

./longhornctl --kube-config ~/.kube/config --image longhornio/longhorn-cli:v1.9.0 install preflight

./longhornctl --kube-config ~/.kube/config  check preflight
```

### Install Longhorn

```bash
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.9.0/deploy/longhorn.yaml

# Monitor installation process
kubectl get pods \
--namespace longhorn-system \
--watch

# Verify the result
kubectl -n longhorn-system get pod
```

### Setup Longhorn dashboard and retain storage

```bash
htpasswd -nb canhcvp1998@gmail.com <password> > longhorn/auth

kubectl create namespace longhorn-system
kubectl -n longhorn-system create secret generic basic-auth --from-file=longhorn/auth

kubectl apply -f longhorn/storageclass.yaml
kubectl apply -f longhorn/ingress.yaml
```

### Setup Backup target

```bash
export AWS_ACCESS_KEY_ID=$(echo -n "your-aws-access-key-id" | tr -d '\n')
export AWS_SECRET_ACCESS_KEY=$(echo -n "your-aws-secret-access-key" | tr -d '\n')
export AWS_ENDPOINTS=$(echo -n "your-s3-endpoint" | tr -d '\n')

kubectl -n longhorn-system delete secret s3-credentials

kubectl -n longhorn-system create secret generic s3-credentials \
  --from-literal=AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  --from-literal=AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  --from-literal=AWS_ENDPOINTS=$AWS_ENDPOINTS
```

Then go to the Longhorn dashboard to setup Backup target with

- URL: s3://<bucket-name>@<region>/
- Credentials: `s3-credentials`
- Poll Interval: 86400 (24h)
