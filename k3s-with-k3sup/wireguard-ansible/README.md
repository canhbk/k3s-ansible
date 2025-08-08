# WireGuard Mesh Network Setup for VPS Infrastructure

This Ansible playbook automates the deployment of a full mesh WireGuard VPN network across multiple VPS servers, creating a secure private network for inter-server communication.

## Overview

This playbook creates a WireGuard mesh topology where:

- Every server connects directly to every other server (full mesh)
- All servers communicate over a private 10.10.0.0/24 subnet
- Each server gets a unique IP in the range 10.10.0.x
- Automatic key generation and distribution
- Configuration is fully automated via Ansible

## Network Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   VPS3      │────▶│   VPS4      │────▶│   VPS6      │
│ 10.10.0.3   │◀────│ 10.10.0.4   │◀────│ 10.10.0.6   │
└─────────────┘     └─────────────┘     └─────────────┘
      │ ▲                 │ ▲                 │ ▲
      │ │                 │ │                 │ │
      ▼ │                 ▼ │                 ▼ │
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   VPS8      │────▶│   VPS9      │────▶│   VPS19     │
│ 10.10.0.8   │◀────│ 10.10.0.9   │◀────│ 10.10.0.19  │
└─────────────┘     └─────────────┘     └─────────────┘
      ...                 ...                 ...

All nodes connect to all other nodes (full mesh topology)
```

## Prerequisites

- Ansible 2.9 or higher installed on your local machine
- SSH access to all target VPS servers
- Root or sudo access on target servers
- Ubuntu/Debian-based VPS servers (for apt package manager)

## Quick Start

1. Clone this repository
2. Copy the inventory template and add your passwords:

   ```bash
   cp inventory/hosts.yaml inventory/hosts.local.yaml
   # Edit hosts.local.yaml to add your passwords
   ```

3. Run the playbook with the local inventory:

   ```bash
   ansible-playbook -i inventory/hosts.local.yaml playbook.yaml
   ```

## Configuration

### Inventory Management

This project uses a two-file approach for inventory management to keep passwords secure:

1. **`inventory/hosts.yaml`** - Public inventory (safe to commit)
   - Contains server IPs, usernames, and WireGuard IPs
   - Passwords are replaced with comments
   - This file is tracked in git

2. **`inventory/hosts.local.yaml`** - Private inventory (gitignored)
   - Contains the same structure WITH actual passwords
   - This file is NOT tracked in git
   - Create this file locally by copying hosts.yaml

### Setting Up Your Inventory

1. The repository includes `hosts.yaml` as a template
2. Create your local inventory with passwords:

   ```bash
   cp inventory/hosts.yaml inventory/hosts.local.yaml
   ```

3. Edit `inventory/hosts.local.yaml` and add your actual passwords:

   ```yaml
   all:
     hosts:
       vps1:
         ansible_host: <PUBLIC_IP>
         ansible_user: root
         ansible_ssh_pass: <YOUR_ACTUAL_PASSWORD>
         wg_ip: 10.10.0.1
   ```

### Using the Inventory

Always use the local inventory file when running playbooks:

```bash
# Correct - uses local file with passwords
ansible-playbook -i inventory/hosts.local.yaml playbook.yaml

# Incorrect - will fail due to missing passwords
ansible-playbook -i inventory/hosts.yaml playbook.yaml
```

### Global Variables

Configuration in `group_vars/all.yaml`:

```yaml
wg_interface: wg0     # WireGuard interface name
wg_port: 51820       # UDP port for WireGuard
```

## Directory Structure

```
.
├── README.md
├── ansible.cfg           # Ansible configuration
├── playbook.yaml        # Main playbook
├── inventory/
│   └── hosts.yaml       # VPS inventory
├── group_vars/
│   └── all.yaml         # Global variables
└── roles/
    └── wireguard/
        ├── tasks/
        │   ├── main.yaml           # Main tasks
        │   └── generate_keys.yaml  # Key generation
        └── templates/
            └── wg0.conf.j2         # WireGuard config template
```

## Security Considerations

### SSH Authentication

**Current setup uses passwords** (visible in inventory). For production:

1. Generate SSH key pair:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/wireguard_ansible
```

2. Copy key to all servers:

```bash
ssh-copy-id -i ~/.ssh/wireguard_ansible.pub root@<SERVER_IP>
```

3. Update inventory to use SSH keys:

```yaml
all:
  hosts:
    vps1:
      ansible_host: <PUBLIC_IP>
      ansible_user: root
      ansible_ssh_private_key_file: ~/.ssh/wireguard_ansible
      wg_ip: 10.10.0.1
```

### Secure Inventory Storage

For sensitive data, use Ansible Vault:

```bash
# Encrypt inventory
ansible-vault encrypt inventory/hosts.yaml

# Run playbook with vault
ansible-playbook -i inventory/hosts.yaml playbook.yaml --ask-vault-pass
```

## How It Works

1. **Key Generation**: Each server generates its own WireGuard private/public key pair
2. **Key Exchange**: Ansible collects all public keys and distributes them
3. **Configuration**: Each server gets a custom config with all peer information
4. **Interface Setup**: WireGuard interface is brought up on each server

## Verification

After deployment, verify the mesh network:

```bash
# On any VPS, check WireGuard status
sudo wg show

# Test connectivity to other nodes
ping 10.10.0.3
ping 10.10.0.4

# Check routing
ip route | grep wg0
```

## Adding/Removing Nodes

### Add a new VPS

1. Add entry to `inventory/hosts.yaml` with unique `wg_ip`
2. Run playbook - it will update all nodes

### Remove a VPS

1. Remove entry from `inventory/hosts.yaml`
2. Run playbook to regenerate configs
3. Manually remove WireGuard on the removed server

## Troubleshooting

### Connection Issues

1. Check WireGuard status:

```bash
sudo wg show
sudo systemctl status wg-quick@wg0
```

2. Verify firewall allows UDP port 51820:

```bash
sudo ufw allow 51820/udp
```

3. Check logs:

```bash
sudo journalctl -u wg-quick@wg0 -f
```

### Common Problems

- **No handshake**: Check firewall rules and public IP accessibility
- **Key errors**: Re-run playbook to regenerate keys
- **Interface down**: `sudo wg-quick up wg0`

## Maintenance

### Update WireGuard

```bash
ansible all -i inventory/hosts.local.yaml -m apt -a "name=wireguard state=latest" --become
```

### Restart all interfaces

```bash
ansible all -i inventory/hosts.local.yaml -m shell -a "wg-quick down wg0 && wg-quick up wg0" --become
```

## Performance Tuning

For better performance, consider:

1. Adjust MTU in the WireGuard config template
2. Enable persistent keepalive for NAT traversal
3. Use UDP port that's not commonly blocked

## License

This project is provided as-is for infrastructure management purposes.
