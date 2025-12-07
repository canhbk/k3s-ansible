# PostgreSQL Secrets Management

## Security Notice

**NEVER commit actual credentials to git!** All secret YAML files in this directory are templates with placeholders.

## Usage

### 1. Create Local Secret File

```bash
# Navigate to cluster directory (e.g., sg3, vn, us)
cd clusters/sg3

# Copy the template
cp secrets-sg3.yaml secrets-sg3.local.yaml

# Edit and replace placeholders
vi secrets-sg3.local.yaml
```

### 2. Replace Placeholders

Common placeholders across clusters:
- `<CHANGE_ME_POSTGRES_PASSWORD>` - Superuser password
- `<CHANGE_ME_APP_PASSWORD>` - Application user password
- `<CHANGE_ME_MURROR_PASSWORD>` - Murror backend user
- `<CHANGE_ME_MURROR_AI_PASSWORD>` - Murror AI service user
- `<CHANGE_ME_REPLICATION_PASSWORD>` - Streaming replication user
- `<CHANGE_ME_MINIO_ACCESS_KEY>` - MinIO access key for backups
- `<CHANGE_ME_MINIO_SECRET_KEY>` - MinIO secret key for backups

### 3. Apply to Cluster

```bash
# Apply the secret
kubectl apply -f secrets-sg3.local.yaml

# Verify
kubectl get secret -n postgres-db
```

### 4. Security Best Practices

- ✅ Use `.local.yaml` suffix for actual credentials (gitignored)
- ✅ Store credentials in password manager
- ✅ Use passwords with minimum 32 characters
- ✅ Rotate credentials every 90 days
- ✅ Different passwords for each environment
- ❌ Never reuse passwords across clusters
- ❌ Never commit `.local.yaml` files to git

## CloudNativePG Integration

These secrets are automatically used by CloudNativePG operator:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: cluster-sg3-pgvector
spec:
  bootstrap:
    initdb:
      secret:
        name: superuser-sg3-secret  # References the secret
```

## Credential Rotation

To rotate PostgreSQL passwords safely:

```bash
# 1. Connect to database
kubectl cnpg psql cluster-name -n postgres-db

# 2. Change password
ALTER USER postgres WITH PASSWORD '<new_password>';
ALTER USER app WITH PASSWORD '<new_password>';

# 3. Update secret
# Edit secrets-sg3.local.yaml with new passwords

# 4. Apply updated secret
kubectl apply -f secrets-sg3.local.yaml

# 5. Restart applications using these credentials
kubectl rollout restart deployment/app-name -n namespace
```

## See Also

- [CloudNativePG Documentation](https://cloudnative-pg.io/)
- [PostgreSQL Security](https://www.postgresql.org/docs/current/auth-pg-hba-conf.html)
- [Project Security Guidelines](../../docs/SECURITY_GUIDELINES.md)
