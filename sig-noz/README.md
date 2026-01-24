# SigNoz installation

## Install

```bash
helm repo add signoz https://charts.signoz.io
helm repo update

helm install signoz signoz/signoz \
   --namespace signoz --create-namespace \
   --wait \
   --timeout 1h \
   -f values.yaml
```

kubectl apply -f ingress.yaml

helm repo add signoz <https://charts.signoz.io>

helm install signoz-k8s-infra signoz/k8s-infra \
   --namespace signoz --create-namespace \
   --wait \
   --timeout 1h \
   -f k8s-infra.yaml

```
