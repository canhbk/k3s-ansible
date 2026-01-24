#!/usr/bin/env bash
# AKHQ Deployment Script for US Kafka Cluster
# Deploys AKHQ with built-in form authentication

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

info "AKHQ Deployment for US Kafka Cluster"
echo "=========================================="
echo

# Step 1: Switch to US cluster context
info "Step 1/6: Switching to US cluster context..."
if kubectl config use-context us &>/dev/null; then
    CURRENT_CONTEXT=$(kubectl config current-context)
    success "Current context: $CURRENT_CONTEXT"
else
    error "Failed to switch to 'us' context. Is it configured?"
    error "Run: kubectl config get-contexts"
    exit 1
fi
echo

# Step 2: Verify Kafka cluster is ready
info "Step 2/6: Verifying Kafka cluster status..."
if kubectl get kafka kafka-us -n kafka &>/dev/null; then
    KAFKA_STATUS=$(kubectl get kafka kafka-us -n kafka -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")

    if [[ "$KAFKA_STATUS" == "True" ]]; then
        success "Kafka cluster 'kafka-us' is Ready"
    else
        warning "Kafka cluster 'kafka-us' status: $KAFKA_STATUS"
        warning "Deployment may fail if Kafka is not ready"
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Deployment cancelled"
            exit 1
        fi
    fi
else
    error "Kafka cluster 'kafka-us' not found in namespace 'kafka'"
    error "Deploy Kafka first: kubectl apply -f ../kafka-cluster.yaml"
    exit 1
fi
echo

# Step 3: Check required secrets
info "Step 3/6: Checking required secrets..."

# Check kafka-admin secret
if kubectl get secret kafka-admin -n kafka &>/dev/null; then
    success "Found 'kafka-admin' secret"
else
    error "Secret 'kafka-admin' not found in namespace 'kafka'"
    error "This secret should be created by Strimzi when KafkaUser is deployed"
    exit 1
fi

# Check akhq-secrets
if kubectl get secret akhq-secrets -n kafka &>/dev/null; then
    success "Found 'akhq-secrets' secret"
else
    error "Secret 'akhq-secrets' not found in namespace 'kafka'"
    error ""
    error "You need to create this secret first!"
    error ""
    error "Steps:"
    error "  1. Copy template: cp secret.yaml.template secret.yaml"
    error "  2. Generate JWT secret: openssl rand -base64 32"
    error "  3. Generate password hashes:"
    error "     python3 -c \"import bcrypt; print(bcrypt.hashpw(b'admin-password', bcrypt.gensalt()).decode())\""
    error "     python3 -c \"import bcrypt; print(bcrypt.hashpw(b'reader-password', bcrypt.gensalt()).decode())\""
    error "  4. Edit secret.yaml with the generated values"
    error "  5. Apply: kubectl apply -f secret.yaml"
    error ""
    error "See README.md for detailed instructions."
    exit 1
fi
echo

# Step 4: Validate manifests
info "Step 4/6: Validating Kubernetes manifests..."
for file in configmap.yaml deployment.yaml service.yaml ingress.yaml; do
    if [[ ! -f "$file" ]]; then
        error "Required file not found: $file"
        exit 1
    fi

    if kubectl apply -f "$file" --dry-run=client &>/dev/null; then
        success "Validated: $file"
    else
        error "Invalid manifest: $file"
        kubectl apply -f "$file" --dry-run=client
        exit 1
    fi
done
echo

# Step 5: Deploy AKHQ
info "Step 5/6: Deploying AKHQ resources..."

info "Applying ConfigMap..."
kubectl apply -f configmap.yaml

info "Applying Deployment..."
kubectl apply -f deployment.yaml

info "Applying Service..."
kubectl apply -f service.yaml

info "Applying Ingress..."
kubectl apply -f ingress.yaml

success "All resources applied successfully"
echo

# Step 6: Wait for deployment
info "Step 6/6: Waiting for AKHQ deployment to be ready..."
if kubectl rollout status deployment/akhq -n kafka --timeout=180s; then
    success "AKHQ deployment is ready!"
else
    error "Deployment rollout failed or timed out"
    error "Check logs: kubectl logs -n kafka -l app=akhq --tail=50"
    exit 1
fi
echo

# Display deployment info
echo "=========================================="
success "AKHQ Deployment Complete!"
echo "=========================================="
echo
info "Access Information:"
echo "  URL: https://akhq.us.canhnv.com"
echo "  Users: admin (full access), reader (read-only)"
echo "  Authentication: Form-based login with BCRYPT"
echo
info "Verification Commands:"
echo "  # Check pod status"
echo "  kubectl get pods -n kafka -l app=akhq"
echo
echo "  # View logs"
echo "  kubectl logs -n kafka -l app=akhq -f"
echo
echo "  # Check ingress"
echo "  kubectl get ingress akhq -n kafka"
echo
echo "  # Check certificate"
echo "  kubectl get certificate -n kafka"
echo
info "Troubleshooting:"
echo "  # If login fails, check password hashes in secret"
echo "  kubectl get secret akhq-secrets -n kafka -o yaml"
echo
echo "  # If Kafka connection fails, check kafka-admin secret"
echo "  kubectl get secret kafka-admin -n kafka -o jsonpath='{.data.password}' | base64 -d"
echo
echo "  # Check AKHQ logs for errors"
echo "  kubectl logs -n kafka -l app=akhq | grep -i error"
echo
info "For complete documentation, see: README.md"
echo
