# Kong Ingress Controller - Operations Runbook

This runbook provides operational procedures for managing Kong Ingress Controller in production.

## Table of Contents

- [Daily Operations](#daily-operations)
- [Health Checks](#health-checks)
- [Common Tasks](#common-tasks)
- [Scaling](#scaling)
- [Upgrades](#upgrades)
- [Backup and Recovery](#backup-and-recovery)
- [Troubleshooting](#troubleshooting)
- [Emergency Procedures](#emergency-procedures)

## Daily Operations

### Morning Checklist

```bash
# 1. Check cluster context
kubectl config current-context

# 2. Check pod health
kubectl get pods -n kong

# 3. Check service status
kubectl get svc -n kong

# 4. Check recent restarts
kubectl get pods -n kong -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}'

# 5. Check Prometheus targets
# Access: http://localhost:9090/targets (port-forward)

# 6. Check Grafana dashboard
# Access: https://grafana.sg3.k3s.canhnv.com

# 7. Review alerts
kubectl get prometheusrule -n monitoring kong-alerts
```

### Weekly Checklist

```bash
# 1. Review resource usage trends
# - Check Grafana CPU/Memory panels
# - Identify growth patterns

# 2. Review error rate trends
# - Check 4xx/5xx rates
# - Identify problematic services

# 3. Review latency trends
# - Check P95/P99 latency
# - Identify slow services

# 4. Check for available updates
helm repo update
helm search repo kong/kong --versions | head -5

# 5. Review audit logs
kubectl logs -n kong -l app.kubernetes.io/name=kong --since=168h | grep ERROR

# 6. Verify backups (if applicable)
# Check backup retention and integrity
```

### Monthly Checklist

```bash
# 1. Review capacity planning
# - CPU/Memory trends
# - Traffic growth
# - Plan for scaling

# 2. Security updates
# - Check Kong CVEs
# - Review plugin updates
# - Update base images

# 3. Documentation review
# - Update operational docs
# - Update runbooks
# - Update troubleshooting guides

# 4. Disaster recovery drill
# - Test backup restore
# - Test cluster failover
# - Update DR procedures
```

## Health Checks

### Pod Health

```bash
# Check all Kong pods
kubectl get pods -n kong

# Expected: All Running with 1/1 READY
# NAME                                    READY   STATUS    RESTARTS   AGE
# kong-kong-5c8d9f4b7-abc12              1/1     Running   0          5d
# kong-kong-5c8d9f4b7-def34              1/1     Running   0          5d
# kong-kong-controller-6789abc-ghi56     1/1     Running   0          5d
# kong-kong-controller-6789abc-jkl78     1/1     Running   0          5d
```

### Service Health

```bash
# Check Kong services
kubectl get svc -n kong

# Verify endpoints
kubectl get endpoints -n kong
```

### Kong Health Check

```bash
# Execute Kong health command
kubectl exec -it -n kong deploy/kong-kong -- kong health

# Expected output:
# {
#   "database": {"ready": true},
#   "proxy": {"ready": true}
# }
```

### Admin API Health

```bash
# Port-forward admin API
kubectl port-forward -n kong svc/kong-kong-admin 8001:8001 &

# Check status
curl http://localhost:8001/status

# Expected: JSON with Kong status

# Check services
curl http://localhost:8001/services | jq .

# Check routes
curl http://localhost:8001/routes | jq .
```

### Metrics Health

```bash
# Port-forward metrics endpoint
kubectl port-forward -n kong svc/kong-kong-status 8100:8100 &

# Check metrics
curl http://localhost:8100/metrics | grep kong_http_requests_total

# Should see metrics output
```

### Ingress Controller Health

```bash
# Check controller logs for errors
kubectl logs -n kong -l app.kubernetes.io/component=controller --tail=50 | grep ERROR

# Check config push status
# In Prometheus: ingress_controller_configuration_push_count{success="true"}
```

## Common Tasks

### View Logs

**Gateway logs**:
```bash
# Live logs
kubectl logs -n kong -l app.kubernetes.io/name=kong -f

# Last 100 lines
kubectl logs -n kong -l app.kubernetes.io/name=kong --tail=100

# From specific pod
kubectl logs -n kong kong-kong-5c8d9f4b7-abc12 -f

# Last hour
kubectl logs -n kong -l app.kubernetes.io/name=kong --since=1h
```

**Controller logs**:
```bash
# Live logs
kubectl logs -n kong -l app.kubernetes.io/component=controller -f

# Last 100 lines
kubectl logs -n kong -l app.kubernetes.io/component=controller --tail=100
```

**Filter logs**:
```bash
# Error logs only
kubectl logs -n kong -l app.kubernetes.io/name=kong --tail=1000 | grep ERROR

# Warning and above
kubectl logs -n kong -l app.kubernetes.io/name=kong --tail=1000 | grep -E "ERROR|WARN"

# Specific service
kubectl logs -n kong -l app.kubernetes.io/name=kong --tail=1000 | grep "service=my-service"
```

### Restart Components

**Rolling restart (zero downtime)**:
```bash
# Restart gateway
kubectl rollout restart deployment/kong-kong -n kong

# Restart controller
kubectl rollout restart deployment/kong-kong-controller -n kong

# Watch rollout
kubectl rollout status deployment/kong-kong -n kong
```

**Force delete pod** (if stuck):
```bash
# Delete specific pod (will be recreated)
kubectl delete pod -n kong kong-kong-5c8d9f4b7-abc12

# Force delete if stuck in Terminating
kubectl delete pod -n kong kong-kong-5c8d9f4b7-abc12 --grace-period=0 --force
```

### View Configuration

**Current Kong configuration**:
```bash
kubectl port-forward -n kong svc/kong-kong-admin 8001:8001 &

# View full config
curl http://localhost:8001/config | jq .

# View services
curl http://localhost:8001/services | jq '.data[] | {name, protocol, host, port}'

# View routes
curl http://localhost:8001/routes | jq '.data[] | {name, hosts, paths}'

# View plugins
curl http://localhost:8001/plugins | jq '.data[] | {name, enabled, config}'
```

**Helm values**:
```bash
# View current Helm values
helm get values kong -n kong

# View all values (including defaults)
helm get values kong -n kong --all
```

### Update Configuration

**Update Helm values**:
```bash
# Edit cluster values
vim apps/kong/clusters/sg3/values.yaml

# Apply changes
./scripts/deploy.sh sg3

# Or use helm directly
helm upgrade kong kong/kong \
  --namespace kong \
  --values apps/kong/base/values-base.yaml \
  --values apps/kong/clusters/sg3/values.yaml
```

**Apply plugin changes**:
```bash
# Edit plugin
vim apps/kong/clusters/sg3/prometheus-plugin.yaml

# Apply
kubectl apply -f apps/kong/clusters/sg3/prometheus-plugin.yaml

# Verify
kubectl get kongclusterplugin prometheus -o yaml
```

### Test Routing

**Create test service**:
```bash
# Deploy httpbin
kubectl create deployment httpbin --image=kennethreitz/httpbin -n default
kubectl expose deployment httpbin --port=80 -n default

# Create ingress
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: httpbin-test
  namespace: default
spec:
  ingressClassName: kong
  rules:
  - host: kong.sg3.canhnv.com
    http:
      paths:
      - path: /test
        pathType: Prefix
        backend:
          service:
            name: httpbin
            port:
              number: 80
EOF

# Test
curl https://kong.sg3.canhnv.com/test/get
```

**Cleanup test**:
```bash
kubectl delete ingress httpbin-test -n default
kubectl delete service httpbin -n default
kubectl delete deployment httpbin -n default
```

### Add Rate Limiting

```bash
# Create plugin
kubectl apply -f - <<EOF
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: rate-limit-test
  namespace: default
config:
  minute: 5
  policy: local
plugin: rate-limiting
EOF

# Apply to ingress
kubectl annotate ingress <ingress-name> -n <namespace> \
  konghq.com/plugins=rate-limit-test

# Test rate limiting
for i in {1..10}; do
  curl -I https://kong.sg3.canhnv.com/your-path
done

# Should see 429 after 5 requests
```

### Add CORS

```bash
# Create CORS plugin
kubectl apply -f - <<EOF
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: cors-config
  namespace: default
config:
  origins:
  - "https://example.com"
  - "https://app.example.com"
  methods:
  - GET
  - POST
  - PUT
  - DELETE
  headers:
  - Authorization
  - Content-Type
  credentials: true
  max_age: 3600
plugin: cors
EOF

# Apply to ingress
kubectl annotate ingress <ingress-name> -n <namespace> \
  konghq.com/plugins=cors-config
```

## Scaling

### Horizontal Scaling

**Scale gateway pods**:
```bash
# Temporary (lost on next deployment)
kubectl scale deployment kong-kong -n kong --replicas=3

# Permanent (edit values.yaml)
vim apps/kong/clusters/sg3/values.yaml
# Change: deployment.kong.replicaCount: 3
./scripts/deploy.sh sg3
```

**Scale controller pods**:
```bash
# Temporary
kubectl scale deployment kong-kong-controller -n kong --replicas=3

# Permanent
vim apps/kong/clusters/sg3/values.yaml
# Change: ingressController.replicaCount: 3
./scripts/deploy.sh sg3
```

**Verify scaling**:
```bash
# Watch pods scale
kubectl get pods -n kong -w

# Check pod distribution across nodes
kubectl get pods -n kong -o wide
```

### Vertical Scaling

**Increase resources**:
```bash
# Edit values
vim apps/kong/clusters/sg3/values.yaml

# Update resources
resources:
  requests:
    cpu: 1
    memory: 2Gi
  limits:
    cpu: 3
    memory: 4Gi

# Apply
./scripts/deploy.sh sg3

# Verify
kubectl describe pod -n kong kong-kong-xxx | grep -A 5 "Limits\|Requests"
```

### Auto-scaling (HPA)

**Create Horizontal Pod Autoscaler**:
```bash
kubectl apply -f - <<EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: kong-kong-hpa
  namespace: kong
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: kong-kong
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
EOF

# Check HPA status
kubectl get hpa -n kong

# Describe HPA
kubectl describe hpa kong-kong-hpa -n kong
```

## Upgrades

### Minor Version Upgrade

**Example: 3.7.x → 3.8.x**

1. **Check release notes**:
   ```bash
   # Visit: https://github.com/Kong/kong/releases
   # Review breaking changes and deprecations
   ```

2. **Update version**:
   ```bash
   vim apps/kong/base/values-base.yaml
   # Update image tag: "3.8.0"
   ```

3. **Test in dev first**:
   ```bash
   ./scripts/deploy.sh dev
   # Verify functionality
   ```

4. **Deploy to production**:
   ```bash
   # Create backup (if using database mode)

   # Deploy
   ./scripts/deploy.sh sg3

   # Watch rollout
   kubectl rollout status deployment/kong-kong -n kong
   ```

5. **Verify**:
   ```bash
   # Check pods
   kubectl get pods -n kong

   # Check version
   kubectl exec -it -n kong deploy/kong-kong -- kong version

   # Test routing
   curl https://kong.sg3.canhnv.com/test

   # Check metrics
   # Review Grafana dashboard
   ```

### Major Version Upgrade

**Example: 3.x → 4.x**

1. **Review migration guide**:
   - Read official migration docs
   - Identify breaking changes
   - Plan migration strategy

2. **Backup configuration**:
   ```bash
   # Export all Kong resources
   kubectl get ingress -A -o yaml > ingress-backup.yaml
   kubectl get kongplugin -A -o yaml > plugins-backup.yaml
   kubectl get kongconsumer -A -o yaml > consumers-backup.yaml
   ```

3. **Test in isolated environment**:
   - Deploy new version in test cluster
   - Run validation tests
   - Verify plugin compatibility

4. **Plan maintenance window**:
   - Schedule downtime if required
   - Notify stakeholders
   - Prepare rollback plan

5. **Execute upgrade**:
   ```bash
   # Update version
   vim apps/kong/base/values-base.yaml

   # Deploy
   ./scripts/deploy.sh sg3
   ```

6. **Validate**:
   - Run smoke tests
   - Check error logs
   - Monitor metrics

7. **Rollback if needed**:
   ```bash
   helm rollback kong -n kong
   ```

### Plugin Upgrade

**Update plugin version**:
```bash
# Check available plugins
kubectl exec -it -n kong deploy/kong-kong -- kong version -vv

# Update plugin in KongPlugin resource
kubectl edit kongplugin <plugin-name> -n <namespace>

# Or update via file
vim apps/kong/clusters/sg3/prometheus-plugin.yaml
kubectl apply -f apps/kong/clusters/sg3/prometheus-plugin.yaml
```

## Backup and Recovery

### Configuration Backup

**DB-less mode** (current setup):
```bash
# Kong configuration is stored in Kubernetes resources
# Backup all Kong CRDs

# Create backup directory
mkdir -p backups/$(date +%Y%m%d)

# Export resources
kubectl get ingress -A -o yaml > backups/$(date +%Y%m%d)/ingress.yaml
kubectl get kongplugin -A -o yaml > backups/$(date +%Y%m%d)/kongplugin.yaml
kubectl get kongclusterplugin -A -o yaml > backups/$(date +%Y%m%d)/kongclusterplugin.yaml
kubectl get kongconsumer -A -o yaml > backups/$(date +%Y%m%d)/kongconsumer.yaml
kubectl get kongingress -A -o yaml > backups/$(date +%Y%m%d)/kongingress.yaml

# Backup Helm values
helm get values kong -n kong > backups/$(date +%Y%m%d)/helm-values.yaml

# Create archive
tar -czf kong-backup-$(date +%Y%m%d).tar.gz backups/$(date +%Y%m%d)/
```

**Automated backup script**:
```bash
#!/bin/bash
# save as: scripts/backup-kong.sh

DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="backups/kong-$DATE"
mkdir -p "$BACKUP_DIR"

echo "Backing up Kong configuration..."

kubectl get ingress -A -o yaml > "$BACKUP_DIR/ingress.yaml"
kubectl get kongplugin -A -o yaml > "$BACKUP_DIR/kongplugin.yaml"
kubectl get kongclusterplugin -A -o yaml > "$BACKUP_DIR/kongclusterplugin.yaml"
kubectl get kongconsumer -A -o yaml > "$BACKUP_DIR/kongconsumer.yaml"
kubectl get kongingress -A -o yaml > "$BACKUP_DIR/kongingress.yaml"
helm get values kong -n kong > "$BACKUP_DIR/helm-values.yaml"

tar -czf "kong-backup-$DATE.tar.gz" "$BACKUP_DIR"
echo "Backup complete: kong-backup-$DATE.tar.gz"
```

### Configuration Restore

```bash
# Extract backup
tar -xzf kong-backup-20260126.tar.gz

# Restore resources
kubectl apply -f backups/kong-20260126/kongclusterplugin.yaml
kubectl apply -f backups/kong-20260126/kongplugin.yaml
kubectl apply -f backups/kong-20260126/kongconsumer.yaml
kubectl apply -f backups/kong-20260126/kongingress.yaml
kubectl apply -f backups/kong-20260126/ingress.yaml

# Verify
kubectl get kongclusterplugin -A
kubectl get ingress -A | grep kong
```

### Disaster Recovery

**Complete cluster rebuild**:

1. **Prepare**:
   - Have backups ready
   - Have infrastructure code ready
   - Have DNS records documented

2. **Deploy Kong**:
   ```bash
   ./scripts/deploy.sh sg3
   ```

3. **Restore configuration**:
   ```bash
   kubectl apply -f backups/latest/
   ```

4. **Verify**:
   ```bash
   # Check all resources
   kubectl get all -n kong
   kubectl get ingress -A

   # Test routing
   curl https://kong.sg3.canhnv.com/test
   ```

## Troubleshooting

### Pods Crash-Looping

**Symptoms**:
- Pods in CrashLoopBackOff state
- High restart count

**Diagnosis**:
```bash
# Check pod status
kubectl describe pod -n kong <pod-name>

# Check logs
kubectl logs -n kong <pod-name> --previous

# Check events
kubectl get events -n kong --sort-by='.lastTimestamp'
```

**Common causes**:
- Configuration error (check Helm values)
- Resource limits too low (increase limits)
- Port conflicts (check port bindings)
- Failed health checks (check probe configuration)

**Resolution**:
```bash
# Fix configuration
vim apps/kong/clusters/sg3/values.yaml

# Redeploy
./scripts/deploy.sh sg3
```

### High Latency

**Symptoms**:
- P95 latency > 500ms
- Slow response times

**Diagnosis**:
```bash
# Check metrics
kubectl port-forward -n kong svc/kong-kong-status 8100:8100
curl http://localhost:8100/metrics | grep latency

# Check Grafana dashboard
# Look at latency breakdown panel
```

**Common causes**:
- Upstream service slow (check backend latency)
- Kong processing slow (check CPU usage)
- Network issues (check node network)
- Plugin overhead (disable plugins to test)

**Resolution**:
```bash
# Scale horizontally
kubectl scale deployment kong-kong -n kong --replicas=3

# Or increase resources
vim apps/kong/clusters/sg3/values.yaml
# Increase CPU/memory limits
./scripts/deploy.sh sg3
```

### High Error Rate

**Symptoms**:
- 5xx error rate > 1%
- Increased 502/503/504 errors

**Diagnosis**:
```bash
# Check error logs
kubectl logs -n kong -l app.kubernetes.io/name=kong --tail=500 | grep -E "ERROR|500|502|503"

# Check upstream health
kubectl port-forward -n kong svc/kong-kong-admin 8001:8001
curl http://localhost:8001/upstreams | jq .
```

**Common causes**:
- Upstream service down (check service endpoints)
- Upstream service overloaded (scale backend)
- Connection timeout (increase timeout)
- Kong overloaded (scale Kong)

**Resolution**:
```bash
# Check upstream endpoints
kubectl get endpoints -n <namespace> <service-name>

# Check backend pods
kubectl get pods -n <namespace> -l app=<app-name>

# Scale backend if needed
kubectl scale deployment <deployment> -n <namespace> --replicas=3
```

### Config Not Applied

**Symptoms**:
- Ingress changes not taking effect
- Plugin configuration not working

**Diagnosis**:
```bash
# Check controller logs
kubectl logs -n kong -l app.kubernetes.io/component=controller --tail=100

# Look for translation errors
kubectl logs -n kong -l app.kubernetes.io/component=controller | grep "translation\|error"

# Check config push status
# In Prometheus: ingress_controller_configuration_push_count
```

**Common causes**:
- Translation error (fix CRD syntax)
- Config push failure (check admin API connectivity)
- CRD validation error (check CRD schema)

**Resolution**:
```bash
# Restart controller
kubectl rollout restart deployment/kong-kong-controller -n kong

# Check admin API
kubectl port-forward -n kong svc/kong-kong-admin 8001:8001
curl http://localhost:8001/config | jq .
```

### Memory Leak

**Symptoms**:
- Memory usage steadily increasing
- OOMKilled restarts

**Diagnosis**:
```bash
# Check memory usage
kubectl top pods -n kong

# Check memory trends in Grafana
# Look at Memory Usage panel

# Check for memory limits
kubectl describe pod -n kong <pod-name> | grep -A 5 Limits
```

**Resolution**:
```bash
# Increase memory limits temporarily
kubectl set resources deployment kong-kong -n kong \
  --limits=memory=4Gi

# Permanent fix
vim apps/kong/clusters/sg3/values.yaml
# Increase memory limits
./scripts/deploy.sh sg3

# If issue persists, may need to upgrade Kong version
```

## Emergency Procedures

### Complete Outage

**All Kong instances down**

1. **Immediate actions**:
   ```bash
   # Check pod status
   kubectl get pods -n kong

   # Check node health
   kubectl get nodes

   # Check events
   kubectl get events -n kong --sort-by='.lastTimestamp' | tail -20
   ```

2. **Quick recovery**:
   ```bash
   # Delete failed pods (will be recreated)
   kubectl delete pod -n kong --all

   # Or restart deployment
   kubectl rollout restart deployment/kong-kong -n kong

   # Watch recovery
   kubectl get pods -n kong -w
   ```

3. **If pods won't start**:
   ```bash
   # Check for resource issues
   kubectl describe nodes | grep -A 5 "Allocated resources"

   # Scale down other services if needed
   # Or add more nodes

   # Redeploy Kong
   helm upgrade kong kong/kong \
     --namespace kong \
     --values apps/kong/base/values-base.yaml \
     --values apps/kong/clusters/sg3/values.yaml \
     --wait
   ```

### Data Loss Prevention

**Before destructive operations**:

1. **Create snapshot**:
   ```bash
   ./scripts/backup-kong.sh
   ```

2. **Verify backup**:
   ```bash
   tar -tzf kong-backup-*.tar.gz
   ```

3. **Proceed with operation**

### Rollback Procedure

**Rollback Helm release**:
```bash
# View history
helm history kong -n kong

# Rollback to previous
helm rollback kong -n kong

# Rollback to specific revision
helm rollback kong 3 -n kong

# Verify
kubectl get pods -n kong
```

**Rollback configuration**:
```bash
# Restore from backup
kubectl apply -f backups/previous/
```

### Emergency Contact List

| Role | Contact | Responsibility |
|------|---------|----------------|
| On-call Engineer | [Contact] | First responder |
| Platform Lead | [Contact] | Escalation point |
| Security Team | [Contact] | Security incidents |
| Network Team | [Contact] | Network issues |

### Incident Response

1. **Detect** - Alerts, monitoring, user reports
2. **Assess** - Severity, impact, root cause
3. **Respond** - Mitigation actions
4. **Communicate** - Stakeholder updates
5. **Resolve** - Restore service
6. **Review** - Post-mortem, prevention

## Next Steps

- [Review monitoring guide](./MONITORING.md)
- [Review deployment guide](./DEPLOYMENT.md)
- [Explore Kong documentation](https://docs.konghq.com/)
