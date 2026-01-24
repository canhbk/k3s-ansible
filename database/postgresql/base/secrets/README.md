# PostgreSQL Secrets Template

This directory contains templates for PostgreSQL secrets. 

**IMPORTANT**: Never commit actual secrets to the repository. Use the templates below and store actual values in a secure secrets management system.

## Secret Template

```yaml
# Superuser secret
apiVersion: v1
kind: Secret
metadata:
  name: superuser-secret
  namespace: postgres-db
type: kubernetes.io/basic-auth
stringData:
  username: postgres
  password: <GENERATE_STRONG_PASSWORD>

---
# Application user secrets
apiVersion: v1
kind: Secret
metadata:
  name: <app-name>-secret
  namespace: postgres-db
type: kubernetes.io/basic-auth
stringData:
  username: <app-username>
  password: <GENERATE_STRONG_PASSWORD>
```

## Password Generation

Generate strong passwords using:

```bash
# Using openssl
openssl rand -base64 20

# Using pwgen
pwgen -s 20 1

# Using /dev/urandom
< /dev/urandom tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' | head -c 20
```

## Best Practices

1. Use unique passwords for each environment
2. Use different passwords for each database user
3. Rotate passwords regularly
4. Never use default or weak passwords
5. Store passwords in a secure secrets management system (e.g., HashiCorp Vault, AWS Secrets Manager)
6. Use Kubernetes secrets with proper RBAC controls
7. Enable encryption at rest for etcd