# Setup PostgreSQL HA

> We are using `CloudNative-PG` to setup postgresql

## Install operator

```bash
  kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.26/releases/cnpg-1.26.0.yaml
```

You can verify that with:

```bash
    kubectl get deploy -n cnpg-system cnpg-controller-manager
```

## Install PostgreSQL

```bash
    kubectl create namespace postgres-db
    kubectl config set-context --current --namespace="postgres-db"

    cd postgres-ha
    kubectl apply -f cluster.yaml
```
