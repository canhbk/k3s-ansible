# Testing Key Preservation in Wireguard Ansible

## Test Procedure

To verify that existing Wireguard keys are preserved when adding a new node:

### 1. Check Current Keys on Existing Nodes

Before running the playbook, SSH into one or more existing nodes and save their current keys:

```bash
# On an existing node (e.g., vps3)
ssh root@84.247.152.54
cat /etc/wireguard/privatekey
wg show wg0 | grep "public key"
```

Save these values for comparison.

### 2. Add New Node to Inventory

Edit `inventory/hosts.local.yaml` and add a new node:

```yaml
vps37:
  ansible_host: <NEW_VPS_IP>
  ansible_user: root
  ansible_ssh_pass: <PASSWORD>
  wg_ip: 10.10.0.37
```

### 3. Run the Playbook

```bash
ansible-playbook -i inventory/hosts.local.yaml playbook.yaml
```

### 4. Verify Keys Remained the Same

SSH back into the existing nodes and verify:

```bash
# On the same existing node
ssh root@84.247.152.54
cat /etc/wireguard/privatekey  # Should be the same as before
wg show wg0 | grep "public key" # Should be the same as before
```

### 5. Verify New Node is Connected

Check that the new node appears in the peer list:

```bash
wg show wg0 | grep -A 5 "10.10.0.37"
```

## Expected Behavior

- Existing nodes keep their original private/public key pairs
- Only the new node generates fresh keys
- All nodes get updated configs to include the new peer
- Wireguard interfaces are restarted with new peer configurations

## Troubleshooting

If keys are still being regenerated:

1. Check the Ansible output for the "Check if private key exists" task - it should show "ok" for existing nodes
2. Verify the conditional logic in generate_keys.yaml is working correctly
3. Run with verbose mode: `ansible-playbook -vvv -i inventory/hosts.local.yaml playbook.yaml`