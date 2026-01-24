#!/bin/bash
# PostgreSQL Deployment Script
# This script helps deploy PostgreSQL clusters using CloudNative-PG

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="postgres-db"
CLUSTER_DIR=""
OPERATOR_VERSION="1.26.0"

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command_exists kubectl; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check if we can connect to the cluster
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    print_info "Prerequisites check passed."
}

# Function to install CloudNative-PG operator
install_operator() {
    print_info "Checking CloudNative-PG operator..."
    
    if kubectl get deploy -n cnpg-system cnpg-controller-manager >/dev/null 2>&1; then
        print_info "CloudNative-PG operator is already installed."
    else
        print_info "Installing CloudNative-PG operator version ${OPERATOR_VERSION}..."
        kubectl apply --server-side -f "https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-${OPERATOR_VERSION%.*}/releases/cnpg-${OPERATOR_VERSION}.yaml"
        
        print_info "Waiting for operator to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment/cnpg-controller-manager -n cnpg-system
        print_info "CloudNative-PG operator installed successfully."
    fi
}

# Function to create namespace
create_namespace() {
    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        print_info "Namespace '$NAMESPACE' already exists."
    else
        print_info "Creating namespace '$NAMESPACE'..."
        kubectl create namespace "$NAMESPACE"
    fi
}

# Function to deploy PostgreSQL cluster
deploy_cluster() {
    local cluster_name="$1"
    
    print_info "Deploying PostgreSQL cluster from $CLUSTER_DIR..."
    
    # Check if secrets file exists
    if [[ -f "$CLUSTER_DIR/secrets.yaml" ]]; then
        print_info "Applying secrets..."
        kubectl apply -f "$CLUSTER_DIR/secrets.yaml" -n "$NAMESPACE"
    else
        print_warning "No secrets.yaml found. Make sure secrets are already deployed."
    fi
    
    # Apply cluster configuration
    if [[ -f "$CLUSTER_DIR/cluster.yaml" ]]; then
        print_info "Applying cluster configuration..."
        kubectl apply -f "$CLUSTER_DIR/cluster.yaml" -n "$NAMESPACE"
    else
        print_error "cluster.yaml not found in $CLUSTER_DIR"
        exit 1
    fi
    
    # Apply additional resources if they exist
    for file in "$CLUSTER_DIR"/*.yaml; do
        if [[ -f "$file" ]] && [[ "$file" != "$CLUSTER_DIR/secrets.yaml" ]] && [[ "$file" != "$CLUSTER_DIR/cluster.yaml" ]]; then
            print_info "Applying $(basename "$file")..."
            kubectl apply -f "$file" -n "$NAMESPACE"
        fi
    done
    
    print_info "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready cluster/postgresql-ha -n "$NAMESPACE" --timeout=600s || {
        print_warning "Cluster is taking longer than expected to be ready. Check status with:"
        echo "kubectl get cluster -n $NAMESPACE"
        echo "kubectl get pods -n $NAMESPACE"
    }
}

# Function to show cluster status
show_status() {
    print_info "PostgreSQL Cluster Status:"
    kubectl get cluster -n "$NAMESPACE"
    echo
    print_info "PostgreSQL Pods:"
    kubectl get pods -n "$NAMESPACE" -l cnpg.io/cluster=postgresql-ha
    echo
    print_info "Services:"
    kubectl get svc -n "$NAMESPACE"
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS] CLUSTER_NAME

Deploy PostgreSQL cluster using CloudNative-PG operator.

Arguments:
    CLUSTER_NAME    Name of the cluster to deploy (e.g., dev, vn, eu, jp, sg, us)

Options:
    -n, --namespace NAMESPACE    Kubernetes namespace (default: postgres-db)
    -v, --version VERSION        CloudNative-PG operator version (default: 1.26.0)
    -s, --status                 Show cluster status after deployment
    -h, --help                   Show this help message

Examples:
    $0 dev                      Deploy dev cluster
    $0 -n my-namespace vn       Deploy vn cluster in custom namespace
    $0 -s eu                    Deploy eu cluster and show status

EOF
}

# Parse command line arguments
SHOW_STATUS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -v|--version)
            OPERATOR_VERSION="$2"
            shift 2
            ;;
        -s|--status)
            SHOW_STATUS=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            CLUSTER_NAME="$1"
            shift
            ;;
    esac
done

# Check if cluster name is provided
if [[ -z "${CLUSTER_NAME:-}" ]]; then
    print_error "Cluster name is required."
    usage
    exit 1
fi

# Set cluster directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_DIR="$(dirname "$SCRIPT_DIR")/clusters/$CLUSTER_NAME"

# Check if cluster directory exists
if [[ ! -d "$CLUSTER_DIR" ]]; then
    print_error "Cluster directory not found: $CLUSTER_DIR"
    print_info "Available clusters:"
    ls -1 "$(dirname "$SCRIPT_DIR")/clusters/" | grep -v production
    exit 1
fi

# Main execution
print_info "Starting PostgreSQL deployment for cluster: $CLUSTER_NAME"

check_prerequisites
install_operator
create_namespace
deploy_cluster "$CLUSTER_NAME"

if [[ "$SHOW_STATUS" == true ]]; then
    echo
    show_status
fi

print_info "PostgreSQL cluster deployment completed successfully!"
print_info "To check status: kubectl get cluster -n $NAMESPACE"