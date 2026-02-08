# AKHQ - Kafka GUI for US Cluster

AKHQ (previously known as KafkaHQ) is a web-based Kafka GUI for managing topics, consumer groups, messages, and cluster configuration.

## Quick Reference

| Property | Value |
|----------|-------|
| URL | https://akhq.us.canhnv.com |
| Authentication | Form-based login (AKHQ native) |
| Password Hashing | BCRYPT |
| Kafka Connection | SASL_PLAINTEXT (SCRAM-SHA-512) |
| Namespace | kafka |
| Default Users | admin, reader |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Internet/Users                       │
└────────────────────┬────────────────────────────────────┘
                     │ HTTPS
                     ↓
┌─────────────────────────────────────────────────────────┐
│  Traefik Ingress (akhq.us.canhnv.com)                  │
│  - TLS termination (cert-manager)                      │
│  - NO basic auth middleware                            │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────┐
│  AKHQ Service (ClusterIP)                              │
│  Port: 80 → 8080                                       │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────┐
│  AKHQ Pod                                              │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Form Authentication (Micronaut Security)        │  │
│  │  - JWT token generation                          │  │
│  │  - BCRYPT password verification                  │  │
│  │  - RBAC (admin, reader roles)                    │  │
│  └──────────────────────────────────────────────────┘  │
│                     │                                   │
│                     ↓                                   │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Kafka Client                                    │  │
│  │  - SASL_PLAINTEXT                                │  │
│  │  - SCRAM-SHA-512                                 │  │
│  │  - Uses kafka-admin credentials                  │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────┬────────────────────────────────────┘
                     │
                     ↓
┌─────────────────────────────────────────────────────────┐
│  Kafka Cluster (kafka-us)                              │
│  - kafka-us-kafka-bootstrap:9092                       │
└─────────────────────────────────────────────────────────┘
```

## Prerequisites

Before deploying AKHQ, ensure:

1. Kafka cluster is running
2. `kafka-admin` secret exists in the `kafka` namespace
3. Cert-manager ClusterIssuer `canhnv-com-prod` is configured
4. You have generated AKHQ authentication secrets

## Secrets Setup

### 1. Generate JWT Secret

```bash
# Generate a random JWT signing secret
openssl rand -base64 32
```

### 2. Generate Password Hashes

You need to hash passwords using BCRYPT. Choose one method:

**Method A: Using Python (recommended)**

```bash
# Install bcrypt if not available
pip3 install bcrypt

# Generate admin password hash
python3 -c "import bcrypt; print(bcrypt.hashpw(b'your-admin-password', bcrypt.gensalt()).decode())"

# Generate reader password hash
python3 -c "import bcrypt; print(bcrypt.hashpw(b'your-reader-password', bcrypt.gensalt()).decode())"
```

**Method B: Using htpasswd (less secure, not recommended)**

```bash
# This uses bcrypt but is less flexible
htpasswd -nbBC 10 admin your-admin-password | cut -d: -f2
htpasswd -nbBC 10 reader your-reader-password | cut -d: -f2
```

**Method C: Online Generator**

Visit https://bcrypt-generator.com/ (ensure you use cost factor 10+)

### 3. Create Secret

Copy the template and fill in the values:

```bash
# Copy template
cp secret.yaml.template secret.yaml

# Edit with your values
# Replace:
#   <GENERATE_WITH_openssl_rand_-base64_32> with JWT secret
#   <BCRYPT_HASH_FOR_ADMIN> with admin password hash
#   <BCRYPT_HASH_FOR_READER> with reader password hash
nano secret.yaml
```

Example secret.yaml (DO NOT commit with real values):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: akhq-secrets
  namespace: kafka
  labels:
    app: akhq
type: Opaque
stringData:
  jwt-secret: "<GENERATE_WITH_openssl_rand_-base64_32>"
  admin-password-hash: "$2b$10$XYZ123..."
  reader-password-hash: "$2b$10$ABC456..."
```

## Deployment

### Quick Deploy

```bash
# Switch to US cluster
kubectl config use-context us

# Run deployment script
./deploy.sh
```

### Manual Deployment

```bash
# Switch to US cluster
kubectl config use-context us

# Verify Kafka cluster is ready
kubectl get kafka kafka-us -n kafka

# Create secrets (one-time)
kubectl apply -f secret.yaml

# Deploy AKHQ
kubectl apply -f configmap.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml

# Wait for deployment
kubectl rollout status deployment/akhq -n kafka

# Verify
kubectl get pods -n kafka -l app=akhq
kubectl get ingress akhq -n kafka
```

## Access

### Login

1. Navigate to https://akhq.us.canhnv.com
2. You'll see the AKHQ login form
3. Enter credentials:
   - **Admin**: username `admin`, password (the one you hashed)
   - **Reader**: username `reader`, password (the one you hashed)

### User Roles

**Admin Role** - Full access:
- View and manage topics
- Produce and consume messages
- Delete messages
- Update topic configurations
- View consumer groups
- Reset consumer group offsets
- View cluster configuration
- Manage schemas (if Schema Registry enabled)
- Manage Kafka Connect (if enabled)

**Reader Role** - Read-only:
- View topics and messages
- View consumer groups
- View cluster configuration
- View schemas (if Schema Registry enabled)
- View Kafka Connect connectors (if enabled)

## User Management

### Add New User

Edit `configmap.yaml` and add to the `basic-auth` section:

```yaml
security:
  basic-auth:
    - username: admin
      password: "${AKHQ_ADMIN_PASSWORD_HASH}"
      groups:
        - admin
    - username: reader
      password: "${AKHQ_READER_PASSWORD_HASH}"
      groups:
        - reader
    - username: newuser  # Add here
      password: "${AKHQ_NEWUSER_PASSWORD_HASH}"
      groups:
        - reader  # or admin
```

Then:

1. Generate password hash for the new user
2. Add the hash to `secret.yaml` as `newuser-password-hash`
3. Update ConfigMap environment variable reference
4. Redeploy

```bash
kubectl apply -f secret.yaml
kubectl apply -f configmap.yaml
kubectl rollout restart deployment/akhq -n kafka
```

### Change User Password

1. Generate new password hash
2. Update secret:

```bash
kubectl edit secret akhq-secrets -n kafka
# Update the password hash (base64 encoded)

# Or recreate the secret
kubectl delete secret akhq-secrets -n kafka
kubectl apply -f secret.yaml
```

3. Restart AKHQ:

```bash
kubectl rollout restart deployment/akhq -n kafka
```

### Custom Roles

To create custom roles, edit `configmap.yaml`:

```yaml
security:
  groups:
    my-custom-role:
      name: my-custom-role
      roles:
        - topic/read
        - topic/data/read
        - topic/insert  # Can create topics
        # See full list of roles in AKHQ documentation
```

Available roles:
- `topic/read`, `topic/insert`, `topic/delete`, `topic/config/update`
- `topic/data/read`, `topic/data/insert`, `topic/data/delete`
- `node/read`, `node/config/update`
- `group/read`, `group/delete`, `group/offsets/update`
- `acls/read`
- `connect/read`, `connect/insert`, `connect/update`, `connect/delete`, `connect/state/update`
- `schema/read`, `schema/insert`, `schema/update`, `schema/delete`, `schema/delete/version`

## Operations

### Check Deployment Status

```bash
# Pod status
kubectl get pods -n kafka -l app=akhq

# Deployment status
kubectl get deployment akhq -n kafka

# Service endpoints
kubectl get svc akhq -n kafka

# Ingress status
kubectl get ingress akhq -n kafka
```

### View Logs

```bash
# Recent logs
kubectl logs -n kafka -l app=akhq --tail=50

# Follow logs
kubectl logs -n kafka -l app=akhq -f

# Check for authentication issues
kubectl logs -n kafka -l app=akhq | grep -i "auth\|login\|401\|403"

# Check Kafka connection issues
kubectl logs -n kafka -l app=akhq | grep -i "kafka\|connection\|bootstrap"
```

### Restart AKHQ

```bash
kubectl rollout restart deployment/akhq -n kafka
kubectl rollout status deployment/akhq -n kafka
```

### Scale AKHQ

```bash
# Scale to 2 replicas for higher availability
kubectl scale deployment/akhq -n kafka --replicas=2

# Scale back to 1
kubectl scale deployment/akhq -n kafka --replicas=1
```

### Resource Usage

```bash
# Check resource consumption
kubectl top pod -n kafka -l app=akhq

# Describe for detailed resource info
kubectl describe pod -n kafka -l app=akhq
```

## Troubleshooting

### Login Issues

**Problem**: Cannot log in, invalid credentials

**Solutions**:

1. Verify password hash is correct:

```bash
# Test password hash locally
python3 -c "import bcrypt; print(bcrypt.checkpw(b'your-password', b'\$2b\$10\$HASH_HERE'))"
```

2. Check secret is properly loaded:

```bash
kubectl get secret akhq-secrets -n kafka -o yaml
# Decode and verify values
```

3. Check AKHQ logs:

```bash
kubectl logs -n kafka -l app=akhq | grep -i "authentication\|login"
```

4. Ensure environment variables are set:

```bash
kubectl describe pod -n kafka -l app=akhq | grep -A5 "Environment:"
```

### Kafka Connection Issues

**Problem**: AKHQ cannot connect to Kafka

**Solutions**:

1. Verify Kafka is running:

```bash
kubectl get kafka kafka-us -n kafka
kubectl get pods -n kafka | grep kafka-us
```

2. Test Kafka connectivity from AKHQ pod:

```bash
# Get pod name
POD=$(kubectl get pod -n kafka -l app=akhq -o jsonpath='{.items[0].metadata.name}')

# Check if bootstrap server is reachable
kubectl exec -it -n kafka $POD -- nc -zv kafka-us-kafka-bootstrap.kafka.svc.cluster.local 9092
```

3. Verify kafka-admin secret exists:

```bash
kubectl get secret kafka-admin -n kafka
kubectl get secret kafka-admin -n kafka -o jsonpath='{.data.password}' | base64 -d
```

4. Check AKHQ Kafka client logs:

```bash
kubectl logs -n kafka -l app=akhq | grep -i "bootstrap\|kafka\|scram"
```

### Certificate Issues

**Problem**: TLS/SSL errors accessing AKHQ

**Solutions**:

1. Check certificate status:

```bash
kubectl get certificate -n kafka
kubectl describe ingress akhq -n kafka
```

2. Verify cert-manager ClusterIssuer:

```bash
kubectl get clusterissuer canhnv-com-prod
kubectl describe clusterissuer canhnv-com-prod
```

3. Check certificate secret:

```bash
kubectl get secret akhq-tls -n kafka
kubectl describe secret akhq-tls -n kafka
```

### Pod Crashes

**Problem**: AKHQ pod keeps restarting

**Solutions**:

1. Check pod events:

```bash
kubectl describe pod -n kafka -l app=akhq
```

2. Check for resource constraints:

```bash
kubectl top pod -n kafka -l app=akhq
```

3. Check logs before crash:

```bash
kubectl logs -n kafka -l app=akhq --previous
```

4. Increase resources if needed:

```yaml
# Edit deployment.yaml
resources:
  requests:
    memory: 512Mi  # Increase from 256Mi
    cpu: 200m      # Increase from 100m
  limits:
    memory: 1Gi    # Increase from 512Mi
    cpu: 1000m     # Increase from 500m
```

### Configuration Issues

**Problem**: AKHQ starts but features not working

**Solutions**:

1. Validate ConfigMap YAML syntax:

```bash
kubectl get configmap akhq-config -n kafka -o yaml
```

2. Check for environment variable expansion:

```bash
kubectl exec -n kafka -l app=akhq -- env | grep AKHQ
kubectl exec -n kafka -l app=akhq -- env | grep KAFKA
```

3. Verify application.yml is mounted:

```bash
POD=$(kubectl get pod -n kafka -l app=akhq -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n kafka $POD -- cat /app/application.yml
```

## Security Considerations

### Password Security

1. **Never commit actual secrets** to version control
2. Use strong passwords (16+ characters, mixed case, numbers, symbols)
3. Rotate passwords periodically
4. Use BCRYPT cost factor of 10+ (default in Python bcrypt)
5. Store password hashes only, never plaintext

### JWT Security

1. Use cryptographically secure random JWT secret (32+ bytes)
2. Rotate JWT secret periodically
3. Keep JWT secret confidential

### Network Security

1. AKHQ uses TLS via Traefik ingress
2. Kafka connection uses SASL authentication
3. Consider adding NetworkPolicy to restrict pod access:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: akhq-network-policy
  namespace: kafka
spec:
  podSelector:
    matchLabels:
      app: akhq
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: traefik
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          strimzi.io/cluster: kafka-us
    ports:
    - protocol: TCP
      port: 9092
```

### Kafka Permissions

AKHQ uses the `kafka-admin` user which has full cluster access. For production:

1. Consider creating a dedicated AKHQ user with limited permissions
2. Use Kafka ACLs to restrict access
3. Example limited user:

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: akhq-user
  namespace: kafka
  labels:
    strimzi.io/cluster: kafka-us
spec:
  authentication:
    type: scram-sha-512
  authorization:
    type: simple
    acls:
      # Read all topics
      - resource:
          type: topic
          name: "*"
          patternType: literal
        operations: [Read, Describe]
      # Read all groups
      - resource:
          type: group
          name: "*"
          patternType: literal
        operations: [Read, Describe]
      # Describe cluster
      - resource:
          type: cluster
        operations: [Describe]
```

## Advanced Configuration

### Enable Audit Logging

Edit `configmap.yaml` to add audit logging:

```yaml
akhq:
  audit:
    enabled: true
    console:
      enabled: true
```

### Connect to Multiple Kafka Clusters

Edit `configmap.yaml`:

```yaml
akhq:
  connections:
    kafka-us:
      properties:
        bootstrap.servers: "kafka-us-kafka-bootstrap.kafka.svc.cluster.local:9092"
        # ... existing config
    kafka-vn:  # Add another cluster
      properties:
        bootstrap.servers: "kafka-vn-kafka-bootstrap.kafka.svc.cluster.local:9092"
        security.protocol: SASL_PLAINTEXT
        sasl.mechanism: SCRAM-SHA-512
        sasl.jaas.config: "..."
```

### Custom UI Options

Edit `configmap.yaml`:

```yaml
akhq:
  ui-options:
    topic:
      default-view: HIDE_INTERNAL  # or ALL, STREAM
      skip-consumer-groups: false
      skip-last-record: true  # Faster topic loading
      show-all-consumer-groups: false
    topic-data:
      sort: OLDEST  # or NEWEST
      size: 50  # Messages per page
      poll-timeout: 1000  # ms
```

## Monitoring

### Prometheus Metrics

AKHQ exposes Prometheus metrics at `/prometheus`:

```yaml
# ServiceMonitor for Prometheus Operator
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: akhq
  namespace: kafka
spec:
  selector:
    matchLabels:
      app: akhq
  endpoints:
  - port: http
    path: /prometheus
    interval: 30s
```

### Health Checks

```bash
# Liveness check
curl https://akhq.us.canhnv.com/health

# Internal check from pod
kubectl exec -n kafka -l app=akhq -- wget -qO- http://localhost:8080/health
```

## Uninstall

```bash
# Switch to US cluster
kubectl config use-context us

# Delete all resources
kubectl delete -f ingress.yaml
kubectl delete -f service.yaml
kubectl delete -f deployment.yaml
kubectl delete -f configmap.yaml

# Optionally delete secrets (CAUTION: Cannot recover passwords)
kubectl delete -f secret.yaml

# Verify cleanup
kubectl get all -n kafka -l app=akhq
```

## Additional Resources

- [AKHQ Documentation](https://akhq.io/docs/)
- [AKHQ GitHub](https://github.com/tchiotludo/akhq)
- [Kafka US Cluster README](../README.md)
- [Strimzi Documentation](https://strimzi.io/docs/)

## Support

For issues or questions:

1. Check logs: `kubectl logs -n kafka -l app=akhq`
2. Review this troubleshooting guide
3. Check AKHQ GitHub issues
4. Verify Kafka cluster health
