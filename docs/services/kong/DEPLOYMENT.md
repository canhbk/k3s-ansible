# Kong Ingress Controller - Deployment Guide

This guide provides detailed instructions for deploying Kong Ingress Controller to Kubernetes clusters.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Pre-Deployment Checklist](#pre-deployment-checklist)
- [Deployment Process](#deployment-process)
- [Post-Deployment Verification](#post-deployment-verification)
- [Configuration](#configuration)
- [Multi-Cluster Deployment](#multi-cluster-deployment)
- [Rollback](#rollback)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Infrastructure Requirements

| Component | Version | Purpose |
|-----------|---------|---------|
| Kubernetes | 1.24+ | Cluster platform (K3s) |
| Helm | 3.x | Package management |
| kubectl | 1.24+ | Cluster management |
| Traefik | 2.x | Primary ingress controller |
| cert-manager | 1.x | TLS certificate automation |
| Prometheus Operator | 0.60+ | Monitoring stack |

### Cluster Requirements

**Minimum Resources per Node**:
- 4 CPU cores
- 8GB RAM
- 20GB storage

**For HA Deployment**:
- At least 2 worker nodes
- Network connectivity between nodes
- Shared storage (if using persistent volumes)

### Access Requirements

1. **Cluster Access**:
   ```bash
   # Verify kubectl access
   kubectl cluster-info
   kubectl get nodes
   ```

2. **Helm Access**:
   ```bash
   # Verify Helm is installed
   helm version
   ```

3. **Context Configuration**:
   ```bash
   # List available contexts
   kubectl config get-contexts

   # Switch to target cluster
   kubectl config use-context sg3
   ```

## Pre-Deployment Checklist

### 1. Verify Existing Components

**Check Traefik Ingress Controller**:
```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
kubectl get svc -n kube-system traefik
```

**Check cert-manager**:
```bash
kubectl get pods -n cert-manager
kubectl get clusterissuer
```

**Check Prometheus Operator**:
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus-operator
```

### 2. Review Configuration

**Clone Repository**:
```bash
git clone <repository-url>
cd k3s-ansible
```

**Review Base Configuration**:
```bash
cat apps/kong/base/values-base.yaml
```

**Review Cluster Configuration**:
```bash
cat apps/kong/clusters/sg3/values.yaml
```

### 3. Prepare DNS

Ensure DNS records are configured:

For SG3 cluster:
- `kong.sg3.canhnv.com` → Traefik LoadBalancer IP
- `api.sg3.canhnv.com` → Traefik LoadBalancer IP
- `kong-admin.sg3.canhnv.com` → Traefik LoadBalancer IP (optional)

**Get Traefik IP**:
```bash
kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### 4. Resource Planning

**Calculate Resource Requirements**:

For HA deployment (2 replicas each):
- Kong Gateway: 2 × (500m CPU + 1Gi RAM) = 1 CPU + 2Gi RAM
- Kong Ingress Controller: 2 × (200m CPU + 256Mi RAM) = 400m CPU + 512Mi RAM
- **Total**: ~1.5 CPU + 2.5Gi RAM

**Verify Node Capacity**:
```bash
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"
```

## Deployment Process

### Method 1: Automated Deployment (Recommended)

The deployment script automates all steps:

```bash
cd apps/kong

# Deploy to SG3 cluster
./scripts/deploy.sh sg3
```

**Script Actions**:
1. Switches to correct kubectl context
2. Creates kong namespace
3. Installs Gateway API CRDs
4. Adds Kong Helm repository
5. Deploys Kong via Helm
6. Applies Prometheus plugin
7. Creates ServiceMonitor
8. Applies Prometheus alerts
9. Creates Ingress resources
10. Deploys Grafana dashboard
11. Waits for pods to be ready
12. Displays deployment information

### Method 2: Manual Deployment

For more control, deploy manually:

#### Step 1: Create Namespace

```bash
kubectl apply -f apps/kong/base/namespace.yaml
```

#### Step 2: Install Gateway API CRDs

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml
```

#### Step 3: Add Kong Helm Repository

```bash
helm repo add kong https://charts.konghq.com
helm repo update
```

#### Step 4: Deploy Kong

```bash
helm upgrade --install kong kong/kong \
  --namespace kong \
  --values apps/kong/base/values-base.yaml \
  --values apps/kong/clusters/sg3/values.yaml \
  --timeout 10m \
  --wait
```

#### Step 5: Apply Monitoring Configuration

```bash
# Prometheus plugin
kubectl apply -f apps/kong/clusters/sg3/prometheus-plugin.yaml

# ServiceMonitor
kubectl apply -f apps/kong/clusters/sg3/servicemonitor.yaml

# Prometheus alerts
kubectl apply -f apps/kong/clusters/sg3/prometheus-alerts.yaml
```

#### Step 6: Create Ingress

```bash
kubectl apply -f apps/kong/clusters/sg3/ingress.yaml
```

#### Step 7: Deploy Grafana Dashboard

```bash
kubectl apply -f monitoring/clusters/sg3/kong-dashboard-configmap.yaml
```

### Monitoring Deployment Progress

**Watch pod creation**:
```bash
kubectl get pods -n kong -w
```

**Check deployment status**:
```bash
kubectl rollout status deployment/kong-kong -n kong
kubectl rollout status deployment/kong-kong-controller -n kong
```

**View logs**:
```bash
# Gateway logs
kubectl logs -n kong -l app.kubernetes.io/name=kong --tail=50 -f

# Controller logs
kubectl logs -n kong -l app.kubernetes.io/component=controller --tail=50 -f
```

## Post-Deployment Verification

### 1. Verify Pods

```bash
kubectl get pods -n kong
```

**Expected Output**:
```
NAME                                    READY   STATUS    RESTARTS   AGE
kong-kong-5c8d9f4b7-abc12              1/1     Running   0          2m
kong-kong-5c8d9f4b7-def34              1/1     Running   0          2m
kong-kong-controller-6789abc-ghi56     1/1     Running   0          2m
kong-kong-controller-6789abc-jkl78     1/1     Running   0          2m
```

### 2. Verify Services

```bash
kubectl get svc -n kong
```

**Expected Services**:
- `kong-kong-proxy` (ClusterIP, ports 80/443)
- `kong-kong-admin` (ClusterIP, port 8001)
- `kong-kong-status` (ClusterIP, port 8100)
- `kong-kong-controller` (ClusterIP, controller metrics)

### 3. Verify Ingress

```bash
kubectl get ingress -n kong
```

**Expected Ingresses**:
- `kong-proxy` (hosts: kong.sg3.canhnv.com, api.sg3.canhnv.com)
- `kong-admin` (host: kong-admin.sg3.canhnv.com)

### 4. Test External Access

```bash
# Test proxy endpoint
curl -I https://kong.sg3.canhnv.com

# Expected: HTTP/2 404 (no routes configured)
```

### 5. Test Admin API

```bash
# Port-forward admin API
kubectl port-forward -n kong svc/kong-kong-admin 8001:8001 &

# Test admin API
curl http://localhost:8001/status

# Expected: JSON response with Kong status
```

### 6. Verify Metrics

```bash
# Port-forward metrics endpoint
kubectl port-forward -n kong svc/kong-kong-status 8100:8100 &

# Fetch metrics
curl http://localhost:8100/metrics | grep kong_

# Expected: Prometheus metrics output
```

### 7. Verify Prometheus Targets

```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &

# Open in browser
open http://localhost:9090/targets

# Search for "kong" - should see 2 targets (gateway + controller)
```

### 8. Verify Grafana Dashboard

```bash
# Open Grafana (adjust URL for your cluster)
open https://grafana.sg3.k3s.canhnv.com

# Search for: "Kong API Gateway - SG3"
# Should see dashboard with panels
```

### 9. Test Kong Health

```bash
kubectl exec -it -n kong deploy/kong-kong -- kong health
```

**Expected Output**:
```
{"database": {"ready": true}, "proxy": {"ready": true}}
```

### 10. Verify CRDs

```bash
kubectl get crd | grep kong
```

**Expected CRDs**:
- kongconsumers.configuration.konghq.com
- kongingresses.configuration.konghq.com
- kongplugins.configuration.konghq.com
- kongclusterplugins.configuration.konghq.com
- tcpingresses.configuration.konghq.com
- udpingresses.configuration.konghq.com

## Configuration

### Customizing Resources

Edit cluster-specific values:

```yaml
# apps/kong/clusters/sg3/values.yaml
resources:
  requests:
    cpu: 1      # Increase CPU
    memory: 2Gi # Increase memory
  limits:
    cpu: 3
    memory: 4Gi
```

Re-deploy:
```bash
./scripts/deploy.sh sg3
```

### Adjusting Replica Count

**Scale up for high traffic**:
```yaml
deployment:
  kong:
    replicaCount: 3
```

**Scale down for development**:
```yaml
deployment:
  kong:
    replicaCount: 1
```

### Enabling Additional Plugins

Kong includes 50+ bundled plugins. To enable custom plugins:

```yaml
# apps/kong/clusters/sg3/values.yaml
env:
  plugins: bundled,custom-plugin-1,custom-plugin-2
```

### Configuring Timeouts

Adjust proxy timeouts for long-running requests:

```yaml
env:
  proxy_read_timeout: 120000  # 120 seconds
  proxy_connect_timeout: 20000
  proxy_send_timeout: 120000
```

## Multi-Cluster Deployment

### Deploying to Additional Clusters

1. **Create cluster directory**:
```bash
mkdir -p apps/kong/clusters/vn
```

2. **Create values.yaml**:
```yaml
# apps/kong/clusters/vn/values.yaml
global:
  additionalLabels:
    cluster: vn
    environment: production

deployment:
  kong:
    replicaCount: 2

resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2
    memory: 2Gi

env:
  kong_cluster_id: vn
  status_listen: "0.0.0.0:8100"
  log_level: warn
```

3. **Copy monitoring configs**:
```bash
cp apps/kong/clusters/sg3/prometheus-plugin.yaml apps/kong/clusters/vn/
cp apps/kong/clusters/sg3/servicemonitor.yaml apps/kong/clusters/vn/
cp apps/kong/clusters/sg3/prometheus-alerts.yaml apps/kong/clusters/vn/

# Update cluster labels in files
sed -i '' 's/sg3/vn/g' apps/kong/clusters/vn/*.yaml
```

4. **Create ingress**:
```yaml
# apps/kong/clusters/vn/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kong-proxy
  namespace: kong
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - kong.vn.canhnv.com
      secretName: kong-proxy-tls
  rules:
    - host: kong.vn.canhnv.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kong-kong-proxy
                port:
                  number: 80
```

5. **Deploy**:
```bash
./scripts/deploy.sh vn
```

## Rollback

### Helm Rollback

**View release history**:
```bash
helm history kong -n kong
```

**Rollback to previous version**:
```bash
helm rollback kong -n kong
```

**Rollback to specific revision**:
```bash
helm rollback kong 2 -n kong
```

### Manual Rollback

1. **Revert to previous values**:
```bash
git log apps/kong/clusters/sg3/values.yaml
git checkout <commit-hash> apps/kong/clusters/sg3/values.yaml
```

2. **Re-deploy**:
```bash
./scripts/deploy.sh sg3
```

### Emergency Rollback

**Delete deployment and start fresh**:
```bash
helm uninstall kong -n kong

# Wait for cleanup
kubectl wait --for=delete pod -l app.kubernetes.io/name=kong -n kong --timeout=60s

# Re-deploy
./scripts/deploy.sh sg3
```

## Troubleshooting

### Pods Not Starting

**Issue**: Pods stuck in Pending or CrashLoopBackOff

**Check**:
```bash
kubectl describe pod -n kong <pod-name>
kubectl logs -n kong <pod-name> --previous
```

**Common Causes**:
- Insufficient resources (increase node capacity or reduce requests)
- Image pull errors (check registry access)
- Configuration errors (verify values.yaml)

### Ingress Not Working

**Issue**: Cannot access Kong via domain

**Check**:
```bash
kubectl describe ingress -n kong kong-proxy
kubectl get endpoints -n kong kong-kong-proxy
```

**Common Causes**:
- DNS not configured (update DNS records)
- Certificate issues (check cert-manager logs)
- Traefik not routing (check Traefik configuration)

### Prometheus Not Scraping

**Issue**: No metrics in Prometheus

**Check**:
```bash
kubectl get servicemonitor -n kong
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus-operator
```

**Common Causes**:
- ServiceMonitor labels incorrect
- Prometheus not watching kong namespace
- Port name mismatch in ServiceMonitor

### High Memory Usage

**Issue**: Kong pods using excessive memory

**Mitigation**:
```bash
# Increase memory limits
# In values.yaml:
resources:
  limits:
    memory: 3Gi

# Or scale horizontally
deployment:
  kong:
    replicaCount: 3
```

### Controller Not Syncing

**Issue**: Kubernetes changes not reflected in Kong

**Check**:
```bash
kubectl logs -n kong -l app.kubernetes.io/component=controller
```

**Look for**:
- Translation errors
- Config push failures
- Connection issues with admin API

**Resolution**:
```bash
# Restart controller
kubectl rollout restart deployment/kong-kong-controller -n kong
```

## Next Steps

- [Configure monitoring and dashboards](./MONITORING.md)
- [Learn day-to-day operations](./OPERATIONS.md)
- [Explore plugin examples](/apps/kong/README.md#plugin-examples)
