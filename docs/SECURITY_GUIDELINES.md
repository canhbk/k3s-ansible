# Security Guidelines for K3s Clusters

This document outlines security best practices and guidelines for different environment types across our K3s infrastructure.

## Environment Security Levels

### 🟢 Development Environment

**Clusters**: `dev`

#### Characteristics

- Relaxed security for developer productivity
- Direct database access allowed
- Simplified authentication
- Verbose logging enabled
- Open network policies

#### Acceptable Practices

- LoadBalancer services for databases
- NodePort services for testing
- Default passwords in code (must be changed in staging/prod)
- Port forwarding for debugging
- Admin access for developers

#### Security Measures Still Required

- No production data copies
- Separate credentials from production
- Basic RBAC implementation
- Regular cluster resets

### 🟡 Staging Environment

**Clusters**: `staging` (if applicable)

#### Characteristics

- Production-like security
- Limited direct access
- Monitoring and alerting enabled
- Network policies enforced

#### Required Security

- No default passwords
- RBAC fully implemented
- Network policies defined
- Audit logging enabled
- Encrypted secrets

### 🔴 Production Environment

**Clusters**: `eu`, `jp`, `sg`, `sg2`, `us`, `vn`, `vn2`

#### Characteristics

- Maximum security enforcement
- No direct database access
- Strict authentication and authorization
- Comprehensive audit logging
- Zero-trust networking

#### Mandatory Security

- All items from staging plus:
- mTLS between services
- Pod security policies/standards
- Regular security scanning
- Incident response procedures
- Compliance requirements (GDPR, etc.)

## Network Security

### Ingress Security

#### Development

```yaml
# Basic ingress with optional auth
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dev-app
  annotations:
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  rules:
  - host: dev-app.domain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app
            port:
              number: 80
```

#### Production

```yaml
# Production ingress with mandatory auth and rate limiting
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prod-app
  annotations:
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.middlewares: "auth-middleware,rate-limit"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - app.domain.com
    secretName: app-tls
  rules:
  - host: app.domain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app
            port:
              number: 80
```

### Database Exposure Guidelines

#### ❌ Never in Production

- Direct internet exposure via LoadBalancer
- NodePort services
- Unencrypted connections
- Default credentials

#### ✅ Production Database Access

1. **VPN Access**
   - Site-to-site VPN for applications
   - Client VPN for administrators

2. **SSH Tunneling**

   ```bash
   # Emergency access only
   ssh -L 5432:postgresql-service:5432 bastion-host
   ```

3. **Private Network**
   - Private VPC/VLAN
   - No public IPs
   - Firewall rules

#### ⚠️ Development Database Access

For the dev cluster PostgreSQL exposure:

```yaml
# development-only-loadbalancer.yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres-external
  namespace: postgres-db
  annotations:
    security/environment: "development-only"
    security/warning: "DO NOT USE IN PRODUCTION"
spec:
  type: LoadBalancer
  selector:
    cnpg.io/cluster: postgresql-ha
    cnpg.io/instanceRole: primary
  ports:
  - port: 5432
    targetPort: 5432
    protocol: TCP
  # Dev only - restrict source IPs
  loadBalancerSourceRanges:
  - "YOUR.OFFICE.IP.RANGE/32"  # Replace with actual IP ranges
  - "DEVELOPER.HOME.IP/32"
```

## Database Administration Tools

### pgAdmin Security

pgAdmin provides browser-based PostgreSQL administration. Security considerations:

#### Production Deployment (SG3, VN, US, etc.)

**Required Security Measures**:
- HTTPS-only access with TLS certificates (cert-manager)
- Built-in authentication (email/password)
- Admin password stored in Kubernetes secret (never in Git)
- **CRITICAL**: Change default admin password immediately after first login
- Network isolation (ClusterIP service, no external LoadBalancer)
- Session cookies: Secure, HttpOnly, SameSite=Lax
- CSRF protection enabled

**Access Pattern**:
```yaml
# pgAdmin ingress with TLS
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: pgadmin
  namespace: postgres-db
  annotations:
    cert-manager.io/cluster-issuer: "canhnv-com-prod"
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - pgadmin.sg3.k3s.canhnv.com
    secretName: pgadmin-sg3-tls
```

**Password Management**:
```bash
# Generate secure admin password
PGADMIN_PASSWORD=$(openssl rand -base64 32)

# Store in secret (never commit to Git)
kubectl create secret generic pgadmin-admin \
  --from-literal=password="$PGADMIN_PASSWORD" \
  -n postgres-db

# Retrieve password for login
kubectl get secret pgadmin-admin -n postgres-db \
  -o jsonpath='{.data.password}' | base64 -d
```

**Security Checklist for pgAdmin**:
- [ ] Admin password changed from default
- [ ] HTTPS-only access enforced
- [ ] TLS certificate valid (Let's Encrypt)
- [ ] No database passwords stored in pgAdmin (prompted on connection)
- [ ] Session timeout configured appropriately
- [ ] Access logs monitored
- [ ] Only necessary users have access

#### Development Deployment

- Basic security acceptable
- Can use simpler passwords
- HTTP acceptable if on isolated network
- Still recommended to use HTTPS with self-signed certs

### Other Database Admin Tools

Similar security principles apply to:
- **phpMyAdmin** (MySQL/MariaDB)
- **Adminer** (multiple databases)
- **RedisInsight** (Redis)

## Secrets Management

### Development

- Kubernetes secrets acceptable
- Can use simple secret generators
- Git-ignored `.env` files

### Production

- External secret management (Vault, AWS Secrets Manager)
- Sealed Secrets for GitOps
- Regular rotation policy
- Encryption at rest

Example with Sealed Secrets:

```bash
# Install sealed-secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/controller.yaml

# Create and seal secret
echo -n mypassword | kubectl create secret generic mysecret \
  --dry-run=client --from-file=password=/dev/stdin -o yaml | \
  kubeseal -o yaml > mysealedsecret.yaml
```

## RBAC Best Practices

### Development RBAC

```yaml
# Permissive for developers
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: dev-admin-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: Group
  name: developers
  apiGroup: rbac.authorization.k8s.io
```

### Production RBAC

```yaml
# Principle of least privilege
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-reader
  namespace: production
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-reader-binding
  namespace: production
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: app-reader
subjects:
- kind: ServiceAccount
  name: app-service-account
  namespace: production
```

## Pod Security Standards

### Development

```yaml
# Permissive for testing
apiVersion: v1
kind: Namespace
metadata:
  name: dev-apps
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/warn: baseline
```

### Production

```yaml
# Restrictive for security
apiVersion: v1
kind: Namespace
metadata:
  name: prod-apps
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/audit: restricted
```

## Network Policies

### Production Example

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgres-network-policy
  namespace: postgres-db
spec:
  podSelector:
    matchLabels:
      cnpg.io/cluster: postgresql-ha
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: approved-apps
    - podSelector:
        matchLabels:
          db-access: "true"
    ports:
    - protocol: TCP
      port: 5432
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 53  # DNS
```

## Security Scanning

### Image Scanning

```bash
# Trivy for vulnerability scanning
trivy image ghcr.io/cloudnative-pg/postgresql:17.5

# In CI/CD pipeline
trivy image --exit-code 1 --severity CRITICAL,HIGH myimage:tag
```

### Cluster Scanning

```bash
# Kubescape for cluster security posture
kubescape scan --submit

# Polaris for best practices
polaris audit --output-file report.yaml
```

## Audit Logging

### Enable K3s Audit Logging

```yaml
# /etc/rancher/k3s/audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: RequestResponse
    omitStages:
    - RequestReceived
    resources:
    - group: ""
      resources: ["secrets", "configmaps"]
    namespaces: ["prod-*", "postgres-db"]
```

## Incident Response

### Security Incident Checklist

1. **Immediate Actions**
   - Isolate affected resources
   - Capture logs and state
   - Notify security team

2. **Investigation**
   - Review audit logs
   - Check for unauthorized access
   - Identify attack vector

3. **Remediation**
   - Patch vulnerabilities
   - Rotate credentials
   - Update security policies

4. **Post-Incident**
   - Document findings
   - Update runbooks
   - Implement preventive measures

## Compliance Considerations

### GDPR (EU Cluster)

- Data residency in EU
- Encryption at rest and in transit
- Access logging and audit trails
- Data retention policies

### SOC2 (US Cluster)

- Change management procedures
- Access control documentation
- Security monitoring
- Incident response procedures

## Security Checklist for New Deployments

### Development

- [ ] No production data
- [ ] Separate credentials
- [ ] Basic RBAC configured
- [ ] Development-only annotations

### Production

- [ ] Security scan passed
- [ ] Network policies defined
- [ ] RBAC implemented
- [ ] Secrets encrypted
- [ ] Monitoring configured
- [ ] Backup strategy defined
- [ ] Incident response plan
- [ ] Compliance requirements met

## Related Documentation

- [Clusters Overview](./CLUSTERS_OVERVIEW.md)
- [Infrastructure Overview](./INFRASTRUCTURE.md)
- [PostgreSQL Security](./services/postgresql/SECURITY.md)
- [RBAC Examples](../cluster-rbac/README.md)
