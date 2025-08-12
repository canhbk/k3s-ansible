# Sensitive Data Management Guide

## Overview
This guide explains how sensitive data is handled for Longhorn deployment to keep credentials and secrets out of git.

## Sensitive Data File: `.secrets.env`

Location: `longhorn/.secrets.env` (gitignored)

This file contains:
- Basic auth credentials
- Backup target credentials (S3, Azure, etc.)
- Private registry credentials
- Certificate configuration

## Initial Setup

1. Copy the template:
```bash
cat > longhorn/.secrets.env << 'EOF'
# Longhorn Sensitive Configuration
LONGHORN_ADMIN_USERNAME=admin
LONGHORN_ADMIN_PASSWORD=your-strong-password-here
LONGHORN_ADMIN_HASH='$(htpasswd -nbB admin your-strong-password-here | cut -d: -f2)'
EOF
```

2. Generate password hash:
```bash
# Install htpasswd if needed
sudo apt-get install apache2-utils  # Debian/Ubuntu
# or
sudo yum install httpd-tools         # RHEL/CentOS

# Generate hash
htpasswd -nbB admin your-password
```

## Using Secrets in Deployment

The deployment script automatically:
1. Checks for `.secrets.env` file
2. Uses `scripts/create-auth-secret.sh` to create Kubernetes secrets
3. Falls back to default credentials if no secrets file exists

## Security Best Practices

1. **Never commit `.secrets.env` to git**
2. **Change default passwords immediately after deployment**
3. **Use strong passwords** (min 12 characters, mixed case, numbers, symbols)
4. **Rotate credentials regularly**
5. **Use different passwords for each environment**

## Managing Secrets Across Teams

For team environments:
- Store secrets in a secure vault (HashiCorp Vault, AWS Secrets Manager, etc.)
- Use environment-specific secret files
- Document the process but never the actual credentials

## Backup Credentials

If using backup targets:
```bash
# Add to .secrets.env
BACKUP_TARGET_URL=s3://your-bucket@region/longhorn-backup
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
```

## Troubleshooting

If auth isn't working:
1. Check if secret exists: `kubectl -n longhorn-system get secret basic-auth`
2. Recreate secret: `./scripts/create-auth-secret.sh`
3. Verify ingress middleware: `kubectl -n longhorn-system get middleware`