# InfluxDB Secrets Management

## Security Notice

**NEVER commit actual credentials to git!** All secret YAML files in this directory are templates with placeholders.

## Usage

### 1. Create Local Secret File

```bash
# Copy the template
cp admin-secret.yaml admin-secret.local.yaml

# Edit and replace placeholders
vi admin-secret.local.yaml
```

### 2. Replace Placeholders

Replace these placeholders with actual credentials:
- `<CHANGE_ME_ADMIN_PASSWORD>` - Strong password for InfluxDB admin user
- `<CHANGE_ME_INFLUXDB_TOKEN>` - API token for backend connections

### 3. Apply to Cluster

```bash
# Apply the secret
kubectl apply -f admin-secret.local.yaml

# Verify
kubectl get secret -n influxdb
```

### 4. Security Best Practices

- ✅ Use `.local.yaml` suffix for actual credentials (gitignored)
- ✅ Store credentials in password manager (1Password, LastPass)
- ✅ Rotate credentials regularly (every 90 days)
- ✅ Use strong, randomly generated passwords
- ❌ Never commit `.local.yaml` files to git
- ❌ Never share credentials via Slack/email

## Credential Rotation

To rotate InfluxDB credentials:

```bash
# 1. Generate new credentials
NEW_PASSWORD=$(openssl rand -base64 32)

# 2. Update secret file
# Edit admin-secret.local.yaml with new password

# 3. Apply to cluster
kubectl apply -f admin-secret.local.yaml

# 4. Restart InfluxDB pods
kubectl rollout restart deployment/influxdb -n influxdb

# 5. Update all applications using these credentials
```

## See Also

- [InfluxDB Security Documentation](https://docs.influxdata.com/influxdb/v2.0/security/)
- [Project Security Guidelines](../../docs/SECURITY_GUIDELINES.md)
