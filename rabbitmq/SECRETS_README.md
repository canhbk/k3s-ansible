# RabbitMQ Secrets Management

## Security Notice

**NEVER commit actual credentials to git!** All secret YAML files in this directory are templates with placeholders.

## Usage

### 1. Create Local Secret File

```bash
# Navigate to cluster directory
cd clusters/sg3

# Copy the template
cp app-rabbitmq-secret.yaml app-rabbitmq-secret.local.yaml

# Edit and replace placeholders
vi app-rabbitmq-secret.local.yaml
```

### 2. Replace Placeholders

- `<CHANGE_ME_ADMIN_PASSWORD>` - RabbitMQ admin user password (full access)
- `<CHANGE_ME_USER_PASSWORD>` - Standard RabbitMQ user password
- `<CHANGE_ME_DEV_PASSWORD>` - Development vhost user password

### 3. Apply to Cluster

```bash
# Apply the secret
kubectl apply -f app-rabbitmq-secret.local.yaml

# Verify
kubectl get secret -n default  # or your app's namespace
```

### 4. Security Best Practices

- ✅ Use `.local.yaml` suffix for actual credentials (gitignored)
- ✅ Admin password: minimum 16 characters with special chars
- ✅ Different passwords for each environment/vhost
- ✅ Rotate credentials every 90 days
- ❌ Never share admin credentials with applications
- ❌ Never commit `.local.yaml` files to git

## RabbitMQ User Types

1. **Admin User** (`admin`)
   - Full access to all vhosts
   - Management UI access
   - Should be used only by administrators

2. **Standard User** (`rabbitmq`)
   - Limited permissions per vhost
   - For general application use
   - Recommended for most applications

3. **Application-Specific Users**
   - `murror-dev`, `murror-preview`, etc.
   - Scoped to specific vhosts
   - Best practice for production

## Credential Rotation

To rotate RabbitMQ passwords:

```bash
# 1. Access RabbitMQ pod
kubectl exec -it rabbitmq-server-0 -n rabbitmq -- bash

# 2. Change password
rabbitmqctl change_password admin '<new_password>'
rabbitmqctl change_password rabbitmq '<new_password>'

# 3. Update secret
# Edit app-rabbitmq-secret.local.yaml with new passwords

# 4. Apply updated secret
kubectl apply -f app-rabbitmq-secret.local.yaml

# 5. Restart applications
kubectl rollout restart deployment/app-name -n namespace
```

## Management UI Access

Access RabbitMQ Management UI:

```bash
# Port-forward
kubectl port-forward -n rabbitmq svc/rabbitmq 15672:15672

# Open browser
open http://localhost:15672

# Login with admin credentials from secret
```

## See Also

- [RabbitMQ Access Control](https://www.rabbitmq.com/access-control.html)
- [RabbitMQ Virtual Hosts](https://www.rabbitmq.com/vhosts.html)
- [Project Security Guidelines](../docs/SECURITY_GUIDELINES.md)
