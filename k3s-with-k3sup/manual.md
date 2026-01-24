
# Setup K3s HA cluster

## Cluster VN1

### Init Control node

vps22

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.32.5+k3s1 INSTALL_K3S_EXEC="server --cluster-init --flannel-iface=wg0 --advertise-address=10.10.0.22 --tls-san=10.10.0.22 --tls-san=14.225.210.108 --tls-san=vps22.canhnv.com  --node-label=region=vn --node-ip=10.10.0.22 --node-external-ip=14.225.210.108 --node-external-dns=vps22.canhnv.com" sh -
```

> Get cluster token

```bash
sudo cat /var/lib/rancher/k3s/server/token
```

### Join 2 control nodes to build k3s HA

- vps24-vnix

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://10.10.0.22:6443 K3S_TOKEN=K107f5d43f397f27d278dbe030f4921e6859c59bc2b3d122355e0492fa31efd84e3::server:c5ab4cde6f13b1712de818957296bd01 INSTALL_K3S_VERSION=v1.32.5+k3s1 INSTALL_K3S_EXEC="server --flannel-iface=wg0 --advertise-address=10.10.0.24 --tls-san=10.10.0.24 --tls-san=14.225.210.170 --tls-san=vps24.canhnv.com --node-label=region=vn --node-ip=10.10.0.24 --node-external-ip=14.225.210.170 --node-external-dns=vps24.canhnv.com" sh -
```

- vps23

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://10.10.0.22:6443 K3S_TOKEN=K107f5d43f397f27d278dbe030f4921e6859c59bc2b3d122355e0492fa31efd84e3::server:c5ab4cde6f13b1712de818957296bd01 INSTALL_K3S_VERSION=v1.32.5+k3s1 INSTALL_K3S_EXEC="server --flannel-iface=wg0 --advertise-address=10.10.0.23 --tls-san=10.10.0.23 --tls-san=14.225.210.165 --tls-san=vps23.canhnv.com --node-label=region=vn --node-ip=10.10.0.23 --node-external-ip=14.225.210.165 --node-external-dns=vps23.canhnv.com" sh -
```

### Join agent nodes

- vps33 (nvme)

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://10.10.0.22:6443 K3S_TOKEN=K107f5d43f397f27d278dbe030f4921e6859c59bc2b3d122355e0492fa31efd84e3::server:c5ab4cde6f13b1712de818957296bd01 INSTALL_K3S_VERSION=v1.32.5+k3s1 INSTALL_K3S_EXEC="--node-label=region=vn --node-label=longhorn=true --node-label=longhorn-region=vn --node-label=role=storage --node-ip=10.10.0.33 --node-external-ip=14.225.210.189 --node-external-dns=vps33.canhnv.com --node-taint=dedicated=storage:NoSchedule" sh -
```

- vps35 (general workload)

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://10.10.0.22:6443 K3S_TOKEN=K107f5d43f397f27d278dbe030f4921e6859c59bc2b3d122355e0492fa31efd84e3::server:c5ab4cde6f13b1712de818957296bd01 INSTALL_K3S_VERSION=v1.32.5+k3s1 INSTALL_K3S_EXEC="--flannel-iface=wg0 --node-label=region=vn --node-label=longhorn=true --node-label=longhorn-region=vn --node-label=role=storage --node-ip=10.10.0.35 --node-external-ip=103.200.23.223" sh -
```

## Cluster 2 (VN)

### Init Control node

vps29-bnix

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.32.5+k3s1 INSTALL_K3S_EXEC="server --cluster-init --cluster-cidr=10.44.0.0/16 --service-cidr=10.45.0.0/16 --cluster-dns=10.45.0.10 --flannel-iface=wg0 --advertise-address=10.10.0.29 --tls-san=10.10.0.29 --tls-san=163.61.73.78 --tls-san=vps29.canhnv.com  --node-label=region=vn2 --node-ip=10.10.0.29 --node-external-ip=163.61.73.78 --node-external-dns=vps29.canhnv.com" sh -
```

### Join 2 control nodes to build k3s HA

vps30-bnix

```bash
curl -sfL https://get.k3s.io | K3S_TOKEN=K105450eefa65ef67b204e99e938b6741fc1be331bba46798f00187fb28dba1c001::server:8995679c473ad175c1b7910f5e0922aa K3S_URL=https://10.10.0.29:6443 INSTALL_K3S_VERSION=v1.32.5+k3s1 INSTALL_K3S_EXEC="server --cluster-cidr=10.44.0.0/16 --service-cidr=10.45.0.0/16 --cluster-dns=10.45.0.10 --flannel-iface=wg0 --advertise-address=10.10.0.30 --tls-san=10.10.0.30 --tls-san=163.61.73.79 --tls-san=vps30.canhnv.com  --node-label=region=vn2 --node-ip=10.10.0.30 --node-external-ip=163.61.73.79 --node-external-dns=vps30.canhnv.com" sh -
```

vps31-bnix

```bash
curl -sfL https://get.k3s.io | K3S_TOKEN=K105450eefa65ef67b204e99e938b6741fc1be331bba46798f00187fb28dba1c001::server:8995679c473ad175c1b7910f5e0922aa K3S_URL=https://10.10.0.29:6443 INSTALL_K3S_VERSION=v1.32.5+k3s1 INSTALL_K3S_EXEC="server --cluster-cidr=10.44.0.0/16 --service-cidr=10.45.0.0/16 --cluster-dns=10.45.0.10 --flannel-iface=wg0 --advertise-address=10.10.0.31 --tls-san=10.10.0.31 --tls-san=163.61.73.90 --tls-san=vps31.canhnv.com  --node-label=region=vn2 --node-ip=10.10.0.31 --node-external-ip=163.61.73.90 --node-external-dns=vps31.canhnv.com" sh -
```

### Join agent nodes

- vps28-bnix

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://10.10.0.29:6443 K3S_TOKEN=K105450eefa65ef67b204e99e938b6741fc1be331bba46798f00187fb28dba1c001::server:8995679c473ad175c1b7910f5e0922aa INSTALL_K3S_VERSION=v1.32.5+k3s1 INSTALL_K3S_EXEC="--flannel-iface=wg0 --node-label=region=vn2 --node-ip=10.10.0.28 --node-external-ip=163.61.73.77 --node-external-dns=vps28.canhnv.com" sh -
```

## Cluster US

### Init Control node

vps26-server-optima

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.32.5+k3s1 INSTALL_K3S_EXEC="server --cluster-init --cluster-cidr=10.46.0.0/16 --service-cidr=10.47.0.0/16 --cluster-dns=10.47.0.10 --flannel-iface=wg0 --advertise-address=10.10.0.26 --tls-san=10.10.0.26 --tls-san=65.49.60.35 --tls-san=vps26.canhnv.com  --node-label=region=us --node-ip=10.10.0.26 --node-external-ip=65.49.60.35 --node-external-dns=vps26.canhnv.com" sh -
```

### Join Agent nodes

- vps27 (us)

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://10.10.0.26:6443 K3S_TOKEN=K10d19dcef01077d4690f024ef61e1e240164416f75fa10ac6f0c802ef8f9b4a47f::server:c5ab4cde6f13b1712de818957296bd01 INSTALL_K3S_VERSION=v1.32.5+k3s1 INSTALL_K3S_EXEC="--flannel-iface=wg0 --node-label=region=us --node-ip=10.10.0.27 --node-external-ip=64.71.161.44 --node-external-dns=vps27.canhnv.com" sh -
```

- vps40 (us)

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://10.10.0.26:6443 K3S_TOKEN=K10d19dcef01077d4690f024ef61e1e240164416f75fa10ac6f0c802ef8f9b4a47f::server:c5ab4cde6f13b1712de818957296bd01 INSTALL_K3S_VERSION=v1.32.5+k3s1 INSTALL_K3S_EXEC="--flannel-iface=wg0 --node-label=region=us --node-ip=10.10.0.40 --node-external-ip=74.82.63.155 --node-external-dns=vps40.canhnv.com" sh -
```

## Cluster EU

### Init Control node

- vps34 (eu)

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.32.5+k3s1 INSTALL_K3S_EXEC="server --cluster-init --cluster-cidr=10.48.0.0/16 --service-cidr=10.49.0.0/16 --cluster-dns=10.49.0.10 --flannel-iface=wg0 --advertise-address=10.10.0.34 --tls-san=10.10.0.34 --tls-san=31.14.17.182 --tls-san=vps34.canhnv.com --node-label=region=eu --node-ip=10.10.0.34 --node-external-ip=31.14.17.182 --node-external-dns=vps34.canhnv.com" sh -
```

### Join Agent nodes

- vps36 (eu)

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://10.10.0.34:6443 K3S_TOKEN=K1044ad04adcd6b11223aa0afe17faa85f178b7a57401cb6fed4979bd68d2c739a1::server:642f0305bdc71ec831212632fdfc8481 INSTALL_K3S_VERSION=v1.32.5+k3s1 INSTALL_K3S_EXEC="--flannel-iface=wg0 --node-label=region=us --node-ip=10.10.0.36 --node-external-ip=203.34.137.95 --node-external-dns=vps36.canhnv.com" sh -
```

## Cluster JP

### Init Control node

- vps3

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.32.5+k3s1 INSTALL_K3S_EXEC="server --cluster-init --cluster-cidr=10.50.0.0/16 --service-cidr=10.51.0.0/16 --cluster-dns=10.51.0.10 --flannel-iface=wg0 --advertise-address=10.10.0.3 --tls-san=10.10.0.3 --tls-san=84.247.152.54 --tls-san=vps3.canhnv.com --node-label=region=eu --node-ip=10.10.0.3 --node-external-ip=84.247.152.54 --node-external-dns=vps3.canhnv.com" sh -
```

### Join Agent nodes

- vps4

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://10.10.0.3:6443 K3S_TOKEN=K10f31a0e306dcdb75965dd0489e0256f7367e35bec42cf6bc20bd4f6010abf2240::server:a6d025c730e560aab878bc59022c47f1 INSTALL_K3S_VERSION=v1.32.5+k3s1 INSTALL_K3S_EXEC="--flannel-iface=wg0 --node-label=region=us --node-ip=10.10.0.4 --node-external-ip=84.247.152.53 --node-external-dns=vps4.canhnv.com" sh -
```

## Cluster Singapore

### Init Control node

- vps9

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.32.5+k3s1 INSTALL_K3S_EXEC="server --cluster-init --cluster-cidr=10.52.0.0/16 --service-cidr=10.53.0.0/16 --cluster-dns=10.53.0.10 --flannel-iface=wg0 --advertise-address=10.10.0.9 --tls-san=10.10.0.9 --tls-san=46.250.232.0 --tls-san=vps9.canhnv.com --node-label=region=eu --node-ip=10.10.0.9 --node-external-ip=46.250.232.0 --node-external-dns=vps9.canhnv.com" sh -
```

### Join Agent nodes

- vps19

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://10.10.0.9:6443 K3S_TOKEN=K108bbed295c70400e44a3148941649ee0fdb15a1e8836f51083eb6964aa525cddf::server:f2cc05cc48ae1049232b2e5d5da5295c INSTALL_K3S_VERSION=v1.32.5+k3s1 INSTALL_K3S_EXEC="--flannel-iface=wg0 --node-label=region=us --node-ip=10.10.0.19 --node-external-ip=62.146.234.36 --node-external-dns=vps19.canhnv.com" sh -
```
