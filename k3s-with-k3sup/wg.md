# Configure Wireguard

## Run on every node

```bash
    sudo apt update
    sudo apt install -y wireguard

    wg genkey | tee privatekey | wg pubkey > publickey
```

## Assign WireGuard IPs

vps22: 10.10.0.22/24

vps23: 10.10.0.23/24

vps24: 10.10.0.24/24

vps26: 10.10.0.26/24

vps27: 10.10.0.27/24

vps31: 10.10.0.31/24

vps33: 10.10.0.33/24

vps36: 10.10.0.36/24

## Create config file on each node

Located at /etc/wireguard/wg0.conf

```ini
# Peer: vps22
[Peer]
PublicKey = z6eYXHSWNoRq8oCp5jxuLaQ15VjDsnwx3efnoydshxI=
AllowedIPs = 10.10.0.22/32
Endpoint = 14.225.210.108:51820
PersistentKeepalive = 25
```

```ini
[Interface]
Address = 10.10.0.22/24
ListenPort = 51820
PrivateKey = __REDACTED__
# (optional) post-up iptables rule to allow forwarding
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT

# Peer: vps23
[Peer]
PublicKey = JKrWflnzkp64L2ZyhNImo7H/Dm1r8sIS89mVY5VgTjU=
AllowedIPs = 10.10.0.23/32
Endpoint = 14.225.210.165:51820
PersistentKeepalive = 25

# Peer: vps24
[Peer]
PublicKey = mURslrU0uqq+jIpfqTJcrrAa5lz2NZLt32enBAVTkAc=
AllowedIPs = 10.10.0.24/32
Endpoint = 14.225.210.170:51820
PersistentKeepalive = 25

# Peer: vps26
[Peer]
PublicKey = XDTl05FjsApmMNyoYAx8zfhL+BtC66kJMuextGIrtkg=
AllowedIPs = 10.10.0.26/32
Endpoint = 65.49.60.35:51820
PersistentKeepalive = 25

# Peer: vps27
[Peer]
PublicKey = ne25jNROxe8k0prHYNG+j9Zy79P6lHbPcyhfAprmkG0=
AllowedIPs = 10.10.0.27/32
Endpoint = 64.71.161.44:51820
PersistentKeepalive = 25

# Peer: vps30
[Peer]
PublicKey = 868ughCTYkgKdptES2VP4kZzchtoRxuVKBJMlk9sbRo=
AllowedIPs = 10.10.0.30/32
Endpoint = 163.61.73.79:51820
PersistentKeepalive = 25

# Peer: vps31
[Peer]
PublicKey = Zrn++HFV8pDIYoMK5ivCvm3Hv3ax/aK/IWv1FQq1UkQ=
AllowedIPs = 10.10.0.31/32
Endpoint = 163.61.73.90:51820
PersistentKeepalive = 25

# Peer: vps33
[Peer]
PublicKey = 3x+J+l50nRsyXddUg3WaS+SuEFSVLl88rohPc8pWm3E=
AllowedIPs = 10.10.0.33/32
Endpoint = 14.225.210.189:51820
PersistentKeepalive = 25

# Peer: vps34
[Peer]
PublicKey = qhfkGPkRWKrV75jg3TDBejtx46bFW7VeksMYJYKWa3A=
AllowedIPs = 10.10.0.34/32
Endpoint = 31.14.17.182:51820
PersistentKeepalive = 25

# Peer: vps36
[Peer]
PublicKey = iwG95fDVTdUId0arhzXmTsigbECW4rX/sJdgm1J192g=
AllowedIPs = 10.10.0.36/32
Endpoint = 203.34.137.95:51820
PersistentKeepalive = 25

# Local Client
PublicKey = 93kezz47244TNMOzsqoYNxhps5t8fsr4cd1e8IyqO38=
AllowedIPs = 10.10.0.250/32
PersistentKeepalive = 25

```

Repeat with appropriate values on all nodes (swap IPs, ports, keys, endpoints).

## Bring up the wireguard interface

On each node

```bash
sudo wg-quick up wg0
```

Verify connectivity:

```bash
sudo wg show
ping 10.10.0.2        # from vps22 to vps23
```

Ensure each can ping all of the others.

## Configure Flannel to use wg0 interface
>
> Do this on all nodes in cluster

- Control nodes

```bash
sudo mkdir -p /etc/rancher/k3s
sudo nano /etc/rancher/k3s/config.yaml

#/etc/rancher/k3s/config.yaml:
flannel-iface: wg0

sudo systemctl restart k3s

#Confirm
sudo journalctl -u k3s | grep flannel
# Look for
The interface wg0 with ipv4 address 10.10.0.X will be used by flannel
```

- Agent nodes

```bash

    sudo mkdir -p /etc/rancher/k3s
    sudo nano /etc/rancher/k3s/config.yaml

    # /etc/rancher/k3s/config.yaml

    flannel-iface: wg0

    sudo systemctl restart k3s-agent

    # Confirm

    sudo journalctl -u k3s-agent | grep flannel

    # Look for

    The interface wg0 with ipv4 address 10.10.0.X will be used by flannel
```

- If both ipv4 and ipv6

```bash
sudo nano /etc/gai.conf

#precedence ::ffff:0:0/96  100
```

## Configure WG client

### MacOS

- Install Wireguard client: <https://apps.apple.com/us/app/wireguard/id1451685025?ls=1&mt=12>
