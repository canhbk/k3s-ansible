# Setup Karmada

## Install CLI

```bash
curl -s https://raw.githubusercontent.com/karmada-io/karmada/master/hack/install-cli.sh | sudo INSTALL_CLI_VERSION=1.14.1 bash
```

```
 karmadactl init \
         --kubeconfig /etc/rancher/k3s/k3s.yaml
          --namespace  karmada-system \
          --etcd-storage-mode PVC \
          --storage-classes-name local-path \
          --etcd-replicas=3 \
          --karmada-apiserver-replicas=3 \
          --karmada-controller-manager-replicas=3 \
          --karmada-scheduler-replicas=3 \
          --karmada-webhook-replicas=3 \
          --cert-external-ip=10.10.0.9
```
