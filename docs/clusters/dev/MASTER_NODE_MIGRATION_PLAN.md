# Master Node Migration Plan: vps7 → vps5-h2cloud-vn

## Executive Summary

This document outlines the complete plan for transferring the master node role from **vps7** (154.26.131.23) to **vps5-h2cloud-vn** (163.61.110.117) in the dev cluster, with vps7 becoming a worker node.

**Migration Date**: [TO BE SCHEDULED]
**Estimated Downtime**: 3-4 hours
**Risk Level**: Medium (Development Environment)

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Migration Strategy](#migration-strategy)
3. [Pre-Migration Checklist](#pre-migration-checklist)
4. [Detailed Implementation Steps](#detailed-implementation-steps)
5. [Rollback Procedures](#rollback-procedures)
6. [Post-Migration Verification](#post-migration-verification)
7. [Risk Assessment](#risk-assessment)

## Current State Analysis

### Cluster Topology

| Node | Current Role | IP Address | OS Version | New Role |
|------|-------------|------------|------------|----------|
| vps7 | control-plane, master | 154.26.131.23 | Ubuntu 20.04.5 LTS | worker |
| vps5-h2cloud-vn | worker | 163.61.110.117 | Ubuntu 22.04.2 LTS | control-plane, master |
| vps16-h2cloud-vn | worker | 160.191.245.234 | Ubuntu 24.04 LTS | worker |
| vps17-h2cloud-vn | worker | 163.61.110.120 | Ubuntu 24.04.1 LTS | worker |
| vps18-h2cloud-vn | worker | 160.250.136.247 | Ubuntu 24.04.1 LTS | worker |
| vps12-h2cloud-vn | worker | 103.157.204.15 | Ubuntu 22.04.2 LTS | worker |
| vps13-h2cloud-vn | worker | 160.191.245.244 | Ubuntu 22.04.5 LTS | worker |

### Technical Details

- **K3s Version**: v1.30.2+k3s1
- **Data Store**: Embedded SQLite (single server mode)
- **Current API Endpoint**: https://154.26.131.23:6443
- **New API Endpoint**: https://163.61.110.117:6443
- **Cluster Token**: __REDACTED__

### Critical Services Running

1. **Databases**:
   - PostgreSQL HA clusters (postgres-db namespace)
   - InfluxDB time-series database (influxdb namespace)
   - Redis cache (redis namespace)
   - MySQL cluster
   - RabbitMQ message broker

2. **Management Tools**:
   - Rancher (cattle-system namespace)
   - Grafana (monitoring namespace)
   - SigNoz APM (platform namespace)

3. **Infrastructure**:
   - Cert-manager (cert-manager namespace)
   - Longhorn storage (longhorn-system namespace)
   - Traefik ingress controller

## Migration Strategy

### Why Complete Rebuild?

K3s single-server mode uses an embedded SQLite database that cannot be migrated to another node. The options are:

1. ❌ **Live Migration**: Not possible with SQLite
2. ❌ **Snapshot & Restore**: High risk of corruption, certificate issues
3. ✅ **Complete Rebuild**: Clean, reliable, predictable outcome

**Selected Strategy**: Complete cluster rebuild with data preservation through backup/restore.

## Pre-Migration Checklist

### One Week Before

- [ ] Schedule maintenance window
- [ ] Notify all stakeholders
- [ ] Review this plan with team
- [ ] Test backup procedures on non-production data
- [ ] Verify SSH access to all nodes
- [ ] Ensure sufficient backup storage (minimum 100GB)

### One Day Before

- [ ] Final review of migration plan
- [ ] Create backup directory structure
- [ ] Test connectivity to all nodes
- [ ] Document current DNS configurations
- [ ] List all external integrations

### Day of Migration

- [ ] Final confirmation from stakeholders
- [ ] Ensure no critical deployments scheduled
- [ ] Have rollback plan ready
- [ ] Team members on standby

## Detailed Implementation Steps

### Phase 1: Complete Backup (60 minutes)

#### 1.1 Create Backup Directory

```bash
# Create timestamped backup directory
export BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
export BACKUP_DIR="/backup/dev-cluster-${BACKUP_DATE}"
mkdir -p ${BACKUP_DIR}
cd ${BACKUP_DIR}

# Set context to dev cluster
kubectl config use-context dev
```

#### 1.2 Backup Kubernetes Resources

```bash
# Document current state
kubectl get nodes -o wide > nodes-before.txt
kubectl get pods -A -o wide > pods-before.txt
kubectl get pvc -A > pvc-before.txt
kubectl get svc -A > services-before.txt
kubectl get ingress -A > ingress-before.txt

# Backup all namespaced resources
for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
  echo "Backing up namespace: $ns"
  kubectl get all,cm,secret,pvc,ingress,ingressroute,networkpolicy -n $ns -o yaml > ${ns}-resources.yaml
done

# Backup cluster-wide resources
kubectl get pv,storageclass,clusterrole,clusterrolebinding -o yaml > cluster-resources.yaml
kubectl get crd -o yaml > crds.yaml

# Backup Helm releases
helm list -A --output yaml > helm-releases.yaml
for release in $(helm list -A -o json | jq -r '.[] | .name + "," + .namespace'); do
  name=$(echo $release | cut -d, -f1)
  ns=$(echo $release | cut -d, -f2)
  helm get values $name -n $ns > helm-values-${name}.yaml
done
```

#### 1.3 Backup Application Data

```bash
# PostgreSQL - Backup all clusters
for cluster in $(kubectl get clusters.postgresql.cnpg.io -A -o jsonpath='{range .items[*]}{.metadata.namespace},{.metadata.name}{"\n"}{end}'); do
  ns=$(echo $cluster | cut -d, -f1)
  name=$(echo $cluster | cut -d, -f2)
  echo "Backing up PostgreSQL cluster: $name in namespace: $ns"

  # Get primary pod
  primary_pod=$(kubectl get pod -n $ns -l cnpg.io/cluster=$name,cnpg.io/instanceRole=primary -o name | head -1)

  if [ ! -z "$primary_pod" ]; then
    kubectl exec -n $ns $primary_pod -- pg_dumpall -U postgres > postgres-${ns}-${name}.sql
  fi
done

# InfluxDB backup
echo "Backing up InfluxDB..."
kubectl exec -n influxdb influxdb-0 -- influx backup /tmp/influxdb-backup
kubectl cp influxdb/influxdb-0:/tmp/influxdb-backup ./influxdb-backup
kubectl exec -n influxdb influxdb-0 -- rm -rf /tmp/influxdb-backup

# Grafana dashboards
echo "Backing up Grafana dashboards..."
kubectl get configmap -n monitoring -o yaml > grafana-configmaps.yaml

# Redis backup (if persistence is enabled)
if kubectl get pvc -n redis | grep -q redis-data; then
  echo "Backing up Redis data..."
  kubectl exec -n redis redis-master-0 -- redis-cli BGSAVE
  sleep 5
  kubectl cp redis/redis-master-0:/data ./redis-backup
fi

# RabbitMQ definitions
echo "Backing up RabbitMQ..."
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl export_definitions /tmp/rabbitmq-definitions.json
kubectl cp rabbitmq/rabbitmq-0:/tmp/rabbitmq-definitions.json ./rabbitmq-definitions.json
```

#### 1.4 Backup Verification

```bash
# Create backup manifest
cat > backup-manifest.txt << EOF
Backup Date: ${BACKUP_DATE}
Cluster: dev
Master Node: vps7 (154.26.131.23)
K3s Version: v1.30.2+k3s1

Files Included:
$(ls -lh ${BACKUP_DIR})

Total Size: $(du -sh ${BACKUP_DIR} | cut -f1)
EOF

# Verify critical files exist
for file in cluster-resources.yaml helm-releases.yaml postgres-*.sql; do
  if [ ! -f "$file" ]; then
    echo "WARNING: Missing backup file: $file"
  fi
done
```

### Phase 2: Cluster Reset (15 minutes)

#### 2.1 Scale Down Applications

```bash
# Optional: Scale down non-critical apps to reduce load
kubectl scale deployment --all --replicas=0 -n monitoring
kubectl scale deployment --all --replicas=0 -n platform
```

#### 2.2 Reset vps7 (Current Master)

```bash
# Connect to vps7
ssh root@154.26.131.23

# Stop K3s service
systemctl stop k3s

# Backup K3s data (optional safety measure)
tar -czf /root/k3s-data-backup.tar.gz /var/lib/rancher/k3s/

# Uninstall K3s completely
/usr/local/bin/k3s-uninstall.sh

# Verify removal
ls /var/lib/rancher/  # Should be empty or not exist
systemctl status k3s   # Should show service not found

# Exit SSH
exit
```

#### 2.3 Clean Other Nodes (Optional)

```bash
# If you want a completely fresh start, reset all agent nodes too
# This is optional but ensures clean state

for node in 160.191.245.234 163.61.110.120 160.250.136.247 103.157.204.15 160.191.245.244 163.61.110.117; do
  echo "Resetting node: $node"
  ssh root@$node "/usr/local/bin/k3s-agent-uninstall.sh || /usr/local/bin/k3s-uninstall.sh || true"
done
```

### Phase 3: Deploy New Cluster (30 minutes)

#### 3.1 Update Inventory File

```bash
# Backup current inventory
cp inventory.dev.local.yml inventory.dev.local.yml.backup

# Create new inventory configuration
cat > inventory.dev.local.yml << 'EOF'
---
k3s_cluster:
  children:
    server:
      hosts:
        163.61.110.117:  # vps5-h2cloud-vn - NEW MASTER
          ansible_user: root
          ansible_ssh_pass: __REDACTED__
    agent:
      hosts:
        154.26.131.23:  # vps7 - NOW AGENT
          ansible_user: root
          ansible_ssh_pass: __REDACTED__
        160.191.245.234:  # vps16-h2cloud-vn
          ansible_user: root
          ansible_ssh_pass: __REDACTED__
        163.61.110.120:  # vps17-h2cloud-vn
          ansible_user: root
          ansible_ssh_pass: __REDACTED__
        160.250.136.247:  # vps18-h2cloud-vn
          ansible_user: root
          ansible_ssh_pass: __REDACTED__
        103.157.204.15:  # vps12-h2cloud-vn
          ansible_user: root
          ansible_ssh_pass: __REDACTED__
        160.191.245.244:  # vps13-h2cloud-vn
          ansible_user: root
          ansible_ssh_pass: __REDACTED__

  vars:
    ansible_port: 22
    ansible_user: debian
    k3s_version: v1.30.2+k3s1
    token: "__REDACTED__"
    api_endpoint: "{{ hostvars[groups['server'][0]]['ansible_host'] | default(groups['server'][0]) }}"
    extra_server_args: "--prefer-bundled-bin"
    extra_agent_args: "--prefer-bundled-bin"
    registries_config_yaml: |
      mirrors:
        docker.io:
          endpoint:
            - "https://registry-1.docker.io"
EOF'
```

#### 3.2 Run Ansible Deployment

```bash
# Change to ansible directory
cd /Users/canhnv/development/canhnv/k3s-ansible

# Test connectivity first
ansible all -i inventory.dev.local.yml -m ping

# Deploy the new cluster
ansible-playbook playbooks/site.yml -i inventory.dev.local.yml -v

# Monitor deployment progress
# Expected output: All tasks should show "ok" or "changed"
```

#### 3.3 Verify New Cluster

```bash
# Update kubeconfig (should happen automatically)
kubectl config use-context k3s-ansible

# Rename context to dev
kubectl config rename-context k3s-ansible dev

# Verify API endpoint
kubectl cluster-info
# Should show: Kubernetes control plane is running at https://163.61.110.117:6443

# Check all nodes
kubectl get nodes -o wide

# Expected output:
# NAME               STATUS   ROLES                  AGE   VERSION
# vps5-h2cloud-vn    Ready    control-plane,master   5m    v1.30.2+k3s1
# vps7               Ready    <none>                 4m    v1.30.2+k3s1
# vps16-h2cloud-vn   Ready    <none>                 4m    v1.30.2+k3s1
# vps17-h2cloud-vn   Ready    <none>                 4m    v1.30.2+k3s1
# vps18-h2cloud-vn   Ready    <none>                 4m    v1.30.2+k3s1
# vps12-h2cloud-vn   Ready    <none>                 4m    v1.30.2+k3s1
# vps13-h2cloud-vn   Ready    <none>                 4m    v1.30.2+k3s1

# Verify system pods
kubectl get pods -n kube-system
```

### Phase 4: Restore Applications (90-120 minutes)

#### 4.1 Install Core Operators

```bash
# CloudNativePG Operator for PostgreSQL
kubectl apply -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.24/releases/cnpg-1.24.0.yaml

# Wait for operator
kubectl wait --for=condition=Available deployment/cnpg-controller-manager -n cnpg-system --timeout=300s

# Cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

# Wait for cert-manager
kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=300s
kubectl wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=300s
kubectl wait --for=condition=Available deployment/cert-manager-cainjector -n cert-manager --timeout=300s

# Longhorn (if used)
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.7.0/deploy/longhorn.yaml

# Traefik CRDs (if not auto-installed)
kubectl apply -f https://raw.githubusercontent.com/traefik/traefik/v3.0/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml
```

#### 4.2 Restore Namespaces and Basic Resources

```bash
cd ${BACKUP_DIR}

# Create namespaces first
kubectl apply -f - << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: postgres-db
---
apiVersion: v1
kind: Namespace
metadata:
  name: influxdb
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
---
apiVersion: v1
kind: Namespace
metadata:
  name: redis
---
apiVersion: v1
kind: Namespace
metadata:
  name: rabbitmq
---
apiVersion: v1
kind: Namespace
metadata:
  name: cattle-system
---
apiVersion: v1
kind: Namespace
metadata:
  name: platform
EOF

# Restore secrets and configmaps first (needed by other resources)
for ns in postgres-db influxdb monitoring redis rabbitmq; do
  echo "Restoring configs for namespace: $ns"
  kubectl apply -f ${ns}-resources.yaml --dry-run=client -o yaml | \
    kubectl apply -f - --field-selector metadata.name!=kubernetes
done
```

#### 4.3 Restore PostgreSQL

```bash
# Apply PostgreSQL cluster definitions
kubectl apply -f database/postgresql/clusters/dev/cluster-basic-test.yaml
kubectl apply -f database/postgresql/clusters/dev/cluster-ha.yaml

# Wait for clusters to be ready
kubectl wait --for=condition=Ready cluster/postgresql-basic-test -n postgres-db --timeout=600s
kubectl wait --for=condition=Ready cluster/postgresql-ha -n postgres-db --timeout=600s

# Restore PostgreSQL data
for backup in postgres-*.sql; do
  ns=$(echo $backup | cut -d- -f2)
  cluster=$(echo $backup | cut -d- -f3 | sed 's/.sql//')

  echo "Restoring PostgreSQL cluster: $cluster in namespace: $ns"

  # Get new primary pod
  primary_pod=$(kubectl get pod -n $ns -l cnpg.io/cluster=$cluster,cnpg.io/instanceRole=primary -o name | head -1)

  if [ ! -z "$primary_pod" ]; then
    cat $backup | kubectl exec -i -n $ns $primary_pod -- psql -U postgres
  fi
done
```

#### 4.4 Restore InfluxDB

```bash
# Deploy InfluxDB
kubectl apply -f monitoring/clusters/dev/influxdb/

# Wait for InfluxDB
kubectl wait --for=condition=Ready pod/influxdb-0 -n influxdb --timeout=300s

# Restore InfluxDB data
kubectl cp ./influxdb-backup influxdb/influxdb-0:/tmp/influxdb-backup
kubectl exec -n influxdb influxdb-0 -- influx restore /tmp/influxdb-backup
kubectl exec -n influxdb influxdb-0 -- rm -rf /tmp/influxdb-backup
```

#### 4.5 Restore Other Services

```bash
# Redis
kubectl apply -f redis/clusters/dev/

# RabbitMQ
kubectl apply -f rabbitmq/clusters/dev/
kubectl wait --for=condition=Ready pod/rabbitmq-0 -n rabbitmq --timeout=300s
kubectl cp ./rabbitmq-definitions.json rabbitmq/rabbitmq-0:/tmp/
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl import_definitions /tmp/rabbitmq-definitions.json

# Grafana dashboards
kubectl apply -f grafana-configmaps.yaml
```

#### 4.6 Restore Helm Applications

```bash
# Add Helm repositories
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Rancher
helm upgrade --install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --create-namespace \
  --set hostname=rancher.dev.canhnv.com \
  --set bootstrapPassword=admin \
  --set replicas=1 \
  -f helm-values-rancher.yaml

# Other Helm releases
while IFS= read -r line; do
  name=$(echo $line | yq e '.name' -)
  namespace=$(echo $line | yq e '.namespace' -)
  chart=$(echo $line | yq e '.chart' -)

  if [ -f "helm-values-${name}.yaml" ]; then
    echo "Restoring Helm release: $name"
    helm upgrade --install $name $chart -n $namespace -f helm-values-${name}.yaml
  fi
done < <(cat helm-releases.yaml | yq e '.[]' -)
```

### Phase 5: Post-Migration Tasks (30 minutes)

#### 5.1 Update DNS Records

Update the following DNS A records:

| Domain | Old IP | New IP | TTL |
|--------|--------|--------|-----|
| dev.k3s.canhnv.com | 154.26.131.23 | 163.61.110.117 | 300 |
| *.dev.canhnv.com | 154.26.131.23 | 163.61.110.117 | 300 |

#### 5.2 Update External Integrations

1. **GitHub Actions/CI-CD**:
   - Update kubeconfig secrets
   - Update API endpoint URLs

2. **Monitoring Systems**:
   - Update Prometheus scrape configs
   - Update external monitoring endpoints

3. **Backup Systems**:
   - Update backup scripts with new master IP
   - Verify backup jobs can connect

#### 5.3 Update Documentation

```bash
# Update cluster documentation
cat > docs/clusters/dev/README.md << 'EOF'
# Dev Cluster Documentation

## Cluster Information

- **Environment**: Development
- **Master Node**: vps5-h2cloud-vn (163.61.110.117)
- **K3s Version**: v1.30.2+k3s1
- **Last Updated**: [Current Date]

## Node Configuration

| Node | Role | IP Address | OS Version | Resources |
|------|------|------------|------------|-----------|
| vps5-h2cloud-vn | control-plane, master | 163.61.110.117 | Ubuntu 22.04.2 LTS | 4 CPU, 8GB RAM |
| vps7 | worker | 154.26.131.23 | Ubuntu 20.04.5 LTS | 4 CPU, 8GB RAM |
| vps16-h2cloud-vn | worker | 160.191.245.234 | Ubuntu 24.04 LTS | 4 CPU, 8GB RAM |
| vps17-h2cloud-vn | worker | 163.61.110.120 | Ubuntu 24.04.1 LTS | 4 CPU, 8GB RAM |
| vps18-h2cloud-vn | worker | 160.250.136.247 | Ubuntu 24.04.1 LTS | 4 CPU, 8GB RAM |
| vps12-h2cloud-vn | worker | 103.157.204.15 | Ubuntu 22.04.2 LTS | 4 CPU, 8GB RAM |
| vps13-h2cloud-vn | worker | 160.191.245.244 | Ubuntu 22.04.5 LTS | 4 CPU, 8GB RAM |

## API Access

- **API Endpoint**: https://163.61.110.117:6443
- **Context Name**: dev

## Migration History

- **[Current Date]**: Master node transferred from vps7 to vps5-h2cloud-vn
EOF'
```

## Post-Migration Verification

### System Health Checks

```bash
# Node health
kubectl get nodes
kubectl top nodes

# System pods
kubectl get pods -n kube-system
kubectl get pods -n kube-public

# All namespaces overview
kubectl get pods -A --field-selector=status.phase!=Running
```

### Application Verification

```bash
# PostgreSQL
kubectl exec -n postgres-db postgresql-ha-1 -- psql -U postgres -c "SELECT version();"

# InfluxDB
kubectl exec -n influxdb influxdb-0 -- influx ping

# Redis
kubectl exec -n redis redis-master-0 -- redis-cli ping

# Check all services
kubectl get svc -A | grep -E "LoadBalancer|NodePort"

# Check ingresses
kubectl get ingress -A
```

### Performance Verification

```bash
# Check resource usage
kubectl top nodes
kubectl top pods -A | sort -k3 -rn | head -20

# Check events for issues
kubectl get events -A --sort-by='.lastTimestamp' | tail -50

# Check for pod restarts
kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount | sort -k3 -rn | head -20
```

### External Access Testing

```bash
# Test Rancher UI
curl -k https://rancher.dev.canhnv.com/ping

# Test other services
curl -k https://signoz.dev.canhnv.com/api/v1/health
curl -k https://grafana.dev.canhnv.com/api/health

# Test database connectivity from outside
psql -h 163.61.110.117 -p 30432 -U postgres -d postgres -c "SELECT 1;"
```

## Rollback Procedures

### Scenario 1: Before Application Restore

If issues occur before restoring applications:

```bash
# Reset the new cluster
ansible-playbook playbooks/reset.yml -i inventory.dev.local.yml

# Restore original inventory
cp inventory.dev.local.yml.backup inventory.dev.local.yml

# Redeploy with vps7 as master
ansible-playbook playbooks/site.yml -i inventory.dev.local.yml
```

### Scenario 2: After Partial Restore

If issues occur during application restore:

```bash
# Option A: Fix and continue
# Identify the failing component
kubectl get pods -A | grep -v Running
kubectl describe pod <failing-pod>

# Fix the issue and continue restoration

# Option B: Full rollback
# Follow Scenario 1 rollback steps
# Then restore from backup
```

### Scenario 3: Post-Migration Issues

If issues are discovered after migration:

```bash
# Document the issues
kubectl get events -A > post-migration-issues.log
kubectl logs -n <namespace> <pod> > pod-issues.log

# Decide on action:
# - Fix forward (recommended for dev)
# - Schedule another maintenance window for rollback
```

## Risk Assessment

### Risk Matrix

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Data Loss | Low | High | Complete backups before migration |
| Extended Downtime | Medium | Medium | Have rollback plan ready |
| Certificate Issues | Medium | Low | New certs will be auto-generated |
| DNS Propagation Delay | Low | Low | Use /etc/hosts for immediate testing |
| Storage Volume Issues | Medium | Medium | Document PV node affinity |
| Network Connectivity | Low | High | Test connectivity before migration |

### Critical Success Factors

1. **Complete Backups**: All data must be backed up successfully
2. **Node Accessibility**: SSH access to all nodes required
3. **DNS Updates**: Quick DNS update capability needed
4. **Team Availability**: Key team members on standby
5. **Rollback Ready**: Rollback procedure tested and ready

## Monitoring Post-Migration

### First 24 Hours

- [ ] Monitor cluster events every hour
- [ ] Check pod restart counts
- [ ] Verify backup jobs are running
- [ ] Monitor resource utilization
- [ ] Check application logs for errors

### First Week

- [ ] Daily health checks
- [ ] Performance baseline comparison
- [ ] User feedback collection
- [ ] Documentation updates
- [ ] Lessons learned meeting

## Communication Plan

### Pre-Migration

```
Subject: Dev Cluster Maintenance - Master Node Migration
To: All Dev Team Members
Date: [Migration Date]
Time: [Start Time] - [End Time]
Impact: Complete cluster unavailability during migration
Action Required: Stop all deployments 1 hour before maintenance
```

### During Migration

- Update team channel every 30 minutes
- Immediate notification if issues arise
- Clear communication on rollback decisions

### Post-Migration

```
Subject: Dev Cluster Migration Complete
Status: [Success/Partial Success/Rolled Back]
New API Endpoint: https://163.61.110.117:6443
Action Required: Update your kubeconfig
Issues: [List any known issues]
```

## Appendix

### A. SSH Commands Quick Reference

```bash
# Connect to new master
ssh root@163.61.110.117  # Password: __REDACTED__

# Connect to old master (now worker)
ssh root@154.26.131.23   # Password: __REDACTED__
```

### B. Useful Kubernetes Commands

```bash
# Get cluster info
kubectl cluster-info
kubectl get nodes -o wide
kubectl get cs  # component status

# Check certificates
kubectl get csr  # certificate signing requests
kubectl get secrets -n kube-system | grep -E "ca-|cert"

# Force delete stuck resources
kubectl delete pod <pod-name> -n <namespace> --grace-period=0 --force
```

### C. Troubleshooting Guide

| Issue | Diagnosis | Solution |
|-------|-----------|----------|
| Node not joining | Check k3s-agent logs | Verify token and API endpoint |
| Pod stuck in Pending | Check events | Verify node resources |
| Service not accessible | Check endpoints | Verify network policies |
| Certificate errors | Check cert expiry | Restart affected pods |

### D. Contact Information

- **Cluster Admin**: [Your Name]
- **Backup Location**: ${BACKUP_DIR}
- **Documentation**: /docs/clusters/dev/
- **Emergency Contact**: [Phone/Slack]

---

**Document Version**: 1.0
**Last Updated**: $(date)
**Next Review**: Post-migration + 7 days