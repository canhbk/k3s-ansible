# Build a Kubernetes cluster using k3s via Ansible

Author: <https://github.com/itwars>

## K3s Ansible Playbook

Build a Kubernetes cluster using Ansible with k3s. The goal is easily install a Kubernetes cluster on machines running:

- [x] Debian
- [x] Ubuntu
- [x] CentOS

on processor architecture:

- [x] x64
- [x] arm64
- [x] armhf

## System requirements

Deployment environment must have Ansible 2.4.0+
Master and nodes must have passwordless SSH access

## Usage

First create a new directory based on the `sample` directory within the `inventory` directory:

```bash
cp -R inventory/sample inventory/my-cluster
```

Second, edit `inventory/my-cluster/hosts.ini` to match the system information gathered above. For example:

```bash
[master]
192.16.35.12

[node]
192.16.35.[10:11]

[k3s_cluster:children]
master
node
```

If needed, you can also edit `inventory/my-cluster/group_vars/all.yml` to match your environment.

Start provisioning of the cluster using the following command:

```bash
ansible-playbook site.yml -i inventory/my-cluster/hosts.ini
```

## Install Nginx Ingress Controller

- kubectl apply -f <https://raw.githubusercontent.com/nginxinc/kubernetes-ingress/v3.2.0/deployments/common/ns-and-sa.yaml>
- kubectl apply -f <https://raw.githubusercontent.com/nginxinc/kubernetes-ingress/v3.2.0/deployments/rbac/rbac.yaml>
- kubectl apply -f <https://raw.githubusercontent.com/nginxinc/kubernetes-ingress/v3.2.0/deployments/rbac/ap-rbac.yaml>
- kubectl apply -f <https://raw.githubusercontent.com/nginxinc/kubernetes-ingress/v3.2.0/deployments/rbac/apdos-rbac.yaml>

- kubectl apply -f <https://raw.githubusercontent.com/nginxinc/kubernetes-ingress/v3.2.0/examples/shared-examples/default-server-secret/default-server-secret.yaml>
- kubectl apply -f <https://raw.githubusercontent.com/nginxinc/kubernetes-ingress/v3.2.0/deployments/common/nginx-config.yaml>
- kubectl apply -f <https://raw.githubusercontent.com/canhbk/kubernetes-ingress/v3.2.0/deployments/common/ingress-class.yaml>

- kubectl apply -f <https://raw.githubusercontent.com/canhbk/kubernetes-ingress/v3.2.0/deployments/common/crds/k8s.nginx.org_virtualservers.yaml>
- kubectl apply -f <https://raw.githubusercontent.com/canhbk/kubernetes-ingress/v3.2.0/deployments/common/crds/k8s.nginx.org_virtualserverroutes.yaml>
- kubectl apply -f <https://raw.githubusercontent.com/canhbk/kubernetes-ingress/v3.2.0/deployments/common/crds/k8s.nginx.org_transportservers.yaml>
- kubectl apply -f <https://raw.githubusercontent.com/canhbk/kubernetes-ingress/v3.2.0/deployments/common/crds/k8s.nginx.org_policies.yaml>
- kubectl apply -f <https://raw.githubusercontent.com/canhbk/kubernetes-ingress/v3.2.0/deployments/common/crds/k8s.nginx.org_globalconfigurations.yaml>

kubectl apply -f <https://raw.githubusercontent.com/canhbk/kubernetes-ingress/v3.2.0/deployments/common/crds/appprotect.f5.com_aplogconfs.yaml>
kubectl apply -f <https://raw.githubusercontent.com/canhbk/kubernetes-ingress/v3.2.0/deployments/common/crds/appprotect.f5.com_appolicies.yaml>
kubectl apply -f <https://raw.githubusercontent.com/canhbk/kubernetes-ingress/v3.2.0/deployments/common/crds/appprotect.f5.com_apusersigs.yaml>

kubectl apply -f <https://raw.githubusercontent.com/canhbk/kubernetes-ingress/v3.2.0/deployments/common/crds/appprotectdos.f5.com_apdoslogconfs.yaml>
kubectl apply -f <https://raw.githubusercontent.com/canhbk/kubernetes-ingress/v3.2.0/deployments/common/crds/appprotectdos.f5.com_apdospolicy.yaml>
kubectl apply -f <https://raw.githubusercontent.com/canhbk/kubernetes-ingress/v3.2.0/deployments/common/crds/appprotectdos.f5.com_dosprotectedresources.yaml>

kubectl apply -f <https://raw.githubusercontent.com/canhbk/kubernetes-ingress/v3.2.0/deployments/deployment/nginx-ingress.yaml>

kubectl apply -f <https://raw.githubusercontent.com/canhbk/kubernetes-ingress/v3.2.0/deployments/service/loadbalancer.yaml>

## Kubeconfig

To get access to your **Kubernetes** cluster just

```bash
scp debian@master_ip:~/.kube/config ~/.kube/config
```

## Setup certificates

- kubectl apply -f <https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml>

- Set token secret at secret-cf-token.yaml
- kubectl apply -f secret-cf-token.yaml
  kubectl apply -f cluster-issuer-staging.yaml

- kubectl apply -f cert-staging.yaml
- kubectl apply -f cert-staging-ode.yaml

## NFS dynamic provisioning

```
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server=154.26.131.23 \
    --set nfs.path=/opt/nfs/k3s-volume \
    --set storageClass.onDelete=true
```
