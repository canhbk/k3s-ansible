# Inventory Management Guide

This guide explains how to manage Ansible inventory files for K3s cluster deployments while keeping sensitive data secure.

## Overview

To protect sensitive information like passwords and tokens, we use a two-file approach:
- **Example files** (`.example`) - Contain the structure without sensitive data, safe for version control
- **Local files** (`.local.yml`) - Contain actual sensitive data, excluded from git

## Quick Start

### 1. Create Your Local Inventory

Copy the example file and fill in your actual values:

```bash
# Copy the example to create your working inventory
cp inventory.yml.example inventory.yml

# Edit with your actual values
vim inventory.yml
```

### 2. Update Sensitive Values

Replace these placeholders with your actual values:
- `YOUR_SERVER_PASSWORD` - SSH password for server nodes
- `YOUR_AGENT*_PASSWORD` - SSH passwords for agent nodes
- `YOUR_CLUSTER_TOKEN` - K3s cluster join token (generate with `openssl rand -base64 64`)

### 3. Use Inventory with Ansible

Run playbooks with your inventory file:

```bash
# Deploy cluster
ansible-playbook playbooks/site.yml -i inventory.yml

# Upgrade cluster
ansible-playbook playbooks/upgrade.yml -i inventory.yml

# Reset cluster
ansible-playbook playbooks/reset.yml -i inventory.yml
```

## File Naming Convention

| Purpose | Example File | Working File |
|---------|--------------|--------------|
| Main/Default | `inventory.yml.example` | `inventory.yml` |
| Sample Template | `inventory-sample.yml` | - |

## Security Best Practices

1. **Never commit local inventory files** - They contain passwords and are automatically ignored by git
2. **Use strong passwords** - Generate secure passwords for SSH access
3. **Use Ansible Vault** (optional) - For additional security, encrypt sensitive values:
   ```bash
   ansible-vault encrypt_string 'your-password' --name 'ansible_ssh_pass'
   ```
4. **Rotate tokens regularly** - Change cluster tokens periodically
5. **Limit file permissions**:
   ```bash
   chmod 600 inventory.*.local.yml
   ```

## Managing Node Changes

When adding or removing nodes:

1. Update your local inventory file (`inventory.yml`)
2. Update the example file (`inventory.yml.example`) with placeholder values
3. Document the change in the example file (e.g., "Node X removed - see commit history")

## Example: Setting Up Your Inventory

1. Copy the example:
   ```bash
   cp inventory.yml.example inventory.yml
   ```

2. Edit the inventory file:
   ```yaml
   server:
     hosts:
       154.26.131.23:
         ansible_user: root
         ansible_ssh_pass: "actual-password-here"
   ```

3. Generate cluster token:
   ```bash
   # Generate token
   openssl rand -base64 64
   # Add to inventory.yml under vars.token
   ```

4. Deploy:
   ```bash
   ansible-playbook playbooks/site.yml -i inventory.yml
   ```

## Troubleshooting

- **File not found**: Ensure you've created the local inventory file from the example
- **Permission denied**: Check SSH passwords and user permissions
- **Git trying to add inventory**: Verify `.gitignore` includes your inventory pattern

## Notes

- Example files should always reflect the current structure of your clusters
- When sharing configurations, always use example files
- Keep local inventory files backed up securely outside the repository