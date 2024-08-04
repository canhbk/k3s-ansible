# Build a Kubernetes cluster using K3s via Ansible

Author: <https://github.com/itwars>
Current Maintainer: <https://github.com/dereknola>

Easily bring up a cluster on machines running:

- [x] Debian
- [x] Ubuntu
- [x] Raspberry Pi OS
- [x] RHEL Family (CentOS, Redhat, Rocky Linux...)
- [x] SUSE Family (SLES, OpenSUSE Leap, Tumbleweed...)
- [x] ArchLinux

on processor architectures:

- [x] x64
- [x] arm64
- [x] armhf

## System requirements

The control node **must** have Ansible 8.0+ (ansible-core 2.15+)

All managed nodes in inventory must have:

- Passwordless SSH access
- Root access (or a user with equivalent permissions)

It is also recommended that all managed nodes disable firewalls and swap. See [K3s Requirements](https://docs.k3s.io/installation/requirements) for more information.

## Usage

First copy the sample inventory to `inventory.yml`.

```bash
cp inventory-sample.yml inventory.yml
```

Second edit the inventory file to match your cluster setup. For example:

```bash
k3s_cluster:
  children:
    server:
      hosts:
        192.16.35.11:
    agent:
      hosts:
        192.16.35.12:
        192.16.35.13:
```

If needed, you can also edit `vars` section at the bottom to match your environment.

If multiple hosts are in the server group the playbook will automatically setup k3s in HA mode with embedded etcd.
An odd number of server nodes is required (3,5,7). Read the [official documentation](https://docs.k3s.io/datastore/ha-embedded) for more information.

Setting up a loadbalancer or VIP beforehand to use as the API endpoint is possible but not covered here.

Start provisioning of the cluster using the following command:

```bash
ansible-playbook playbooks/site.yml -i inventory.yml
```

### Using an external database

If an external database is preferred, this can be achieved by passing the `--datastore-endpoint` as an extra server argument as well as setting the `use_external_database` flag to true.

```bash
k3s_cluster:
  children:
    server:
      hosts:
        192.16.35.11:
        192.16.35.12:
    agent:
      hosts:
        192.16.35.13:

  vars:
    use_external_database: true
    extra_server_args: "--datastore-endpoint=postgres://username:password@hostname:port/database-name"
```

The `use_external_database` flag is required when more than one server is defined, as otherwise an embedded etcd cluster will be created instead.

The format of the datastore-endpoint parameter is dependent upon the datastore backend, please visit the [K3s datastore endpoint format](https://docs.k3s.io/datastore#datastore-endpoint-format-and-functionality) for details on the format and supported datastores.

## Upgrading

A playbook is provided to upgrade K3s on all nodes in the cluster. To use it, update `k3s_version` with the desired version in `inventory.yml` and run:

```bash
ansible-playbook playbooks/upgrade.yml -i inventory.yml
```

## Uninstall

```bash
ansible-playbook playbooks/reset.yml -i inventory.yml
```

## Setup NFS storage

- Required helm installed on your local machine
- Add the repo

  ```bash
   helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
  ```

- Installation
  Right now, I use the master node as NFS server, instead setup a separate NFS server. As I tested, this only work if installed in the default namespace

  ```bash
   helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=<master_ip> \
  --set nfs.path=/opt/nfs/k3s-volume \
  --set storageClass.name=nfs-client \
  --set storageClass.provisionerName=nfs-vps7 \
  --set nfs.mountOptions="{nfsvers=4}"
  ```

- Uninstall NFS provisioner

  ```bash
    helm delete nfs-subdir-external-provisioner
  ```

## Kubeconfig

After successful bringup, the kubeconfig of the cluster is copied to the control node and merged with `~/.kube/config` under the `k3s-ansible` context.
Assuming you have [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) installed, you can confirm access to your **Kubernetes** cluster with the following:

```bash
kubectl config use-context k3s-ansible
kubectl get nodes
```

If you wish for your kubeconfig to be copied elsewhere and not merged, you can set the `kubeconfig` variable in `inventory.yml` to the desired path.

## Local Testing

A Vagrantfile is provided that provision a 5 nodes cluster using Vagrant (LibVirt or Virtualbox as provider). To use it:

```bash
vagrant up
```

By default, each node is given 2 cores and 2GB of RAM and runs Ubuntu 20.04. You can customize these settings by editing the `Vagrantfile`.
