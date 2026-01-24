k3sup install --ip 14.225.210.108 --user root --cluster --k3s-version v1.32.5+k3s1 --ssh-key ~/.ssh/canhnv_vps

mkdir -p ~/.ssh
chmod 700 ~/.ssh

nano ~/.ssh/authorized_keys
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIVz8CfLd+i3/Dzye5XGC9OCRQLkvkb9Ep1eieblV7Ms <canhnv@CANHs-MacBook-Pro.local>

chmod 600 ~/.ssh/authorized_keys

# vps23

k3sup join \
  --ip 14.225.210.165 \
  --user root \
  --server-user root \
  --server-ip 14.225.210.108 \
  --server \
  --k3s-version v1.32.5+k3s1 \
--server-ssh-port 22 \
--ssh-port 22 \
  --ssh-key ~/.ssh/canhnv_vps

# vps24

k3sup join \
  --ip 14.225.210.170 \
  --user root \
  --server-user root \
  --server-ip 14.225.210.108 \
  --server \
  --k3s-version v1.32.5+k3s1 \
--server-ssh-port 22 \
--ssh-port 22 \
  --ssh-key ~/.ssh/canhnv_vps

# vps31

k3sup join \
  --ip 163.61.73.90 \
  --user root \
  --server-user root \
  --server-ip 14.225.210.108 \
  --server \
  --k3s-version v1.32.5+k3s1 \
--server-ssh-port 22 \
--ssh-port 22 \
  --ssh-key ~/.ssh/canhnv_vps

# vps33 - nvme - dedicated cpu

k3sup join \
  --ip 14.225.210.189 \
  --user root \
  --server-user root \
  --server-ip 14.225.210.108 \
  --k3s-version v1.32.5+k3s1 \
  --server-ssh-port 22 \
  --ssh-port 22 \
  --ssh-key ~/.ssh/canhnv_vps

# vps26 - master - US location

k3sup join \
  --ip 65.49.60.35 \
  --user client_3419_1 \
  --server-user root \
  --server-ip 14.225.210.108 \
  --server \
  --k3s-version v1.32.5+k3s1 \
  --server-ssh-port 22 \
  --ssh-port 22 \
  --ssh-key ~/.ssh/canhnv_vps

## Install treafik CRD

```bash
kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v3.3.6/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml
```

kubectl label node vps33-vnix-nvme-dedicated-cpu node-role.kubernetes.io/postgres=
