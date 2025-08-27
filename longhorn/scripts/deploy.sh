#!/bin/bash
# Longhorn deployment script for multi-cluster setup

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
CLUSTER=""
NAMESPACE="longhorn-system"
DRY_RUN=false
HELM_RELEASE="longhorn"
HELM_REPO="https://charts.longhorn.io"
HELM_CHART="longhorn/longhorn"
CHART_VERSION="1.9.1"

# Function to print colored output
print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to show usage
usage() {
    cat << EOF
Usage: $0 -c CLUSTER [-n NAMESPACE] [-d] [-v VERSION]

Deploy Longhorn to a specific Kubernetes cluster

Options:
    -c CLUSTER      Cluster name (required: dev, vn, eu, jp, sg, sg2, us, vn2)
    -n NAMESPACE    Namespace to deploy to (default: longhorn-system)
    -d              Dry run mode
    -v VERSION      Chart version (default: 1.9.1)
    -h              Show this help message

Examples:
    $0 -c dev                    # Deploy to dev cluster
    $0 -c vn -d                  # Dry run for vn cluster
    $0 -c dev -v 1.7.2          # Deploy specific version

EOF
    exit 1
}

# Parse command line arguments
while getopts "c:n:v:dh" opt; do
    case ${opt} in
        c) CLUSTER=$OPTARG ;;
        n) NAMESPACE=$OPTARG ;;
        v) CHART_VERSION=$OPTARG ;;
        d) DRY_RUN=true ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Validate cluster parameter
if [ -z "$CLUSTER" ]; then
    print_error "Cluster name is required"
    usage
fi

# Check if cluster is valid
VALID_CLUSTERS=("dev" "vn" "eu" "jp" "sg" "sg2" "us" "vn2")
if [[ ! " ${VALID_CLUSTERS[@]} " =~ " ${CLUSTER} " ]]; then
    print_error "Invalid cluster: $CLUSTER"
    print_error "Valid clusters: ${VALID_CLUSTERS[*]}"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Check if cluster-specific values file exists
CLUSTER_VALUES="${BASE_DIR}/clusters/${CLUSTER}/values.yaml"
BASE_VALUES="${BASE_DIR}/base/values-base.yaml"

if [ ! -f "$CLUSTER_VALUES" ]; then
    print_error "Cluster values file not found: $CLUSTER_VALUES"
    exit 1
fi

if [ ! -f "$BASE_VALUES" ]; then
    print_error "Base values file not found: $BASE_VALUES"
    exit 1
fi

# Switch to cluster context
print_info "Switching to cluster context: $CLUSTER"
kubectl config use-context "$CLUSTER"

# Verify cluster connection
print_info "Verifying cluster connection..."
if ! kubectl cluster-info &>/dev/null; then
    print_error "Cannot connect to cluster $CLUSTER"
    exit 1
fi

# Add Longhorn Helm repository
print_info "Adding Longhorn Helm repository..."
helm repo add longhorn "$HELM_REPO" >/dev/null 2>&1
helm repo update >/dev/null 2>&1

# Create namespace if it doesn't exist
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    print_info "Creating namespace: $NAMESPACE"
    if [ "$DRY_RUN" = false ]; then
        kubectl create namespace "$NAMESPACE"
    else
        echo "kubectl create namespace $NAMESPACE"
    fi
fi

# Prepare Helm command
HELM_CMD="helm upgrade --install $HELM_RELEASE $HELM_CHART"
HELM_CMD="$HELM_CMD --namespace $NAMESPACE"
HELM_CMD="$HELM_CMD --version $CHART_VERSION"
HELM_CMD="$HELM_CMD -f $BASE_VALUES"
HELM_CMD="$HELM_CMD -f $CLUSTER_VALUES"

if [ "$DRY_RUN" = true ]; then
    HELM_CMD="$HELM_CMD --dry-run --debug"
fi

# Check and install prerequisites
print_info "Checking Longhorn prerequisites..."

# Download longhornctl if not present
LONGHORNCTL_VERSION="v1.9.1"
LONGHORNCTL_PATH="${BASE_DIR}/longhornctl"

if [ ! -f "$LONGHORNCTL_PATH" ]; then
    print_info "Downloading longhornctl ${LONGHORNCTL_VERSION}..."
    ARCH=$(uname -m)
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')

    # Map architecture
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *) print_error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac

    DOWNLOAD_URL="https://github.com/longhorn/cli/releases/download/${LONGHORNCTL_VERSION}/longhornctl-${OS}-${ARCH}"

    if command -v curl &>/dev/null; then
        curl -sSfL "$DOWNLOAD_URL" -o "$LONGHORNCTL_PATH"
    elif command -v wget &>/dev/null; then
        wget -q "$DOWNLOAD_URL" -O "$LONGHORNCTL_PATH"
    else
        print_error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi

    chmod +x "$LONGHORNCTL_PATH"
    print_info "longhornctl downloaded successfully"
fi

# Check prerequisites
print_info "Checking cluster prerequisites..."
KUBECONFIG_PATH="${KUBECONFIG:-$HOME/.kube/config}"
if ! "$LONGHORNCTL_PATH" check preflight --kube-config="$KUBECONFIG_PATH"; then
    print_warn "Prerequisites check failed. Installing prerequisites..."

    if [ "$DRY_RUN" = false ]; then
        print_info "Installing Longhorn prerequisites..."
        
        # Install NFS utilities
        print_info "Installing NFS utilities..."
        kubectl apply -f "https://raw.githubusercontent.com/longhorn/longhorn/v${CHART_VERSION}/deploy/prerequisite/longhorn-nfs-installation.yaml"
        
        # Install iSCSI utilities
        print_info "Installing iSCSI utilities..."
        kubectl apply -f "https://raw.githubusercontent.com/longhorn/longhorn/v${CHART_VERSION}/deploy/prerequisite/longhorn-iscsi-installation.yaml"
        
        # Create DaemonSet for dm_crypt module
        print_info "Creating DaemonSet to load dm_crypt module..."
        cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: enable-dm-crypt
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: enable-dm-crypt
  template:
    metadata:
      labels:
        name: enable-dm-crypt
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: enable-dm-crypt
        image: alpine
        command: ["nsenter", "--target", "1", "--mount", "--uts", "--ipc", "--net", "--pid", "--", "sh", "-c", "modprobe dm_crypt && echo 'dm_crypt module loaded' && sleep infinity"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: host-modules
          mountPath: /lib/modules
          readOnly: true
      volumes:
      - name: host-modules
        hostPath:
          path: /lib/modules
EOF

        # Wait for prerequisites to be ready
        print_info "Waiting for prerequisites to be ready..."
        sleep 60

        # Check again
        if ! "$LONGHORNCTL_PATH" check preflight --kube-config="$KUBECONFIG_PATH"; then
            print_warn "Some prerequisites may still be missing. Continuing anyway..."
        fi
    else
        print_warn "DRY RUN: Would install prerequisites:"
        print_warn "  - NFS utilities via Longhorn DaemonSet"
        print_warn "  - iSCSI utilities via Longhorn DaemonSet" 
        print_warn "  - dm_crypt kernel module via custom DaemonSet"
    fi
else
    print_info "All prerequisites are satisfied"
fi

# Deploy Longhorn
print_info "Deploying Longhorn to cluster: $CLUSTER"
print_info "Using base values: $BASE_VALUES"
print_info "Using cluster values: $CLUSTER_VALUES"
print_info "Chart version: $CHART_VERSION"

if [ "$DRY_RUN" = true ]; then
    print_warn "Running in DRY RUN mode"
fi

echo
echo "Executing: $HELM_CMD"
echo

# Execute Helm command
eval "$HELM_CMD"

if [ "$DRY_RUN" = false ]; then
    print_info "Waiting for Longhorn deployment to be ready..."

    # Wait for Longhorn manager to be ready
    kubectl -n "$NAMESPACE" wait --for=condition=ready pod -l app=longhorn-manager --timeout=300s || true

    # Apply additional resources
    # Apply storage classes - check for cluster-specific first
    CLUSTER_STORAGECLASS="${BASE_DIR}/clusters/${CLUSTER}/storageclass.yaml"
    if [ -f "$CLUSTER_STORAGECLASS" ]; then
        print_info "Applying cluster-specific storage classes..."
        kubectl apply -f "$CLUSTER_STORAGECLASS"
    else
        print_info "Applying base storage classes..."
        kubectl apply -f "${BASE_DIR}/base/storageclass-base.yaml"
    fi

    # Apply cluster-specific ingress if exists
    CLUSTER_INGRESS="${BASE_DIR}/clusters/${CLUSTER}/ingress.yaml"
    if [ -f "$CLUSTER_INGRESS" ]; then
        print_info "Applying cluster-specific ingress..."
        kubectl apply -f "$CLUSTER_INGRESS"
    fi

    # Create basic auth secret if it doesn't exist
    if ! kubectl -n "$NAMESPACE" get secret basic-auth &>/dev/null; then
        print_warn "Creating basic-auth secret..."
        if [ -x "${BASE_DIR}/scripts/create-auth-secret.sh" ]; then
            "${BASE_DIR}/scripts/create-auth-secret.sh"
        else
            print_warn "Using default credentials (admin/admin) - CHANGE IMMEDIATELY!"
            kubectl -n "$NAMESPACE" create secret generic basic-auth \
                --from-literal=users='admin:$2y$10$2uYKkb7sKlSUifqLLxLYLe3xNfUGGVBXqeAc.AG3irF7S9CgzG8Ee'
        fi
    fi

    print_info "Deployment completed successfully!"
    print_info "Longhorn UI will be available at: https://${CLUSTER}.longhorn.canhnv.com"

    # Show status
    echo
    print_info "Longhorn pods status:"
    kubectl -n "$NAMESPACE" get pods

    echo
    print_info "Storage classes:"
    kubectl get storageclass | grep longhorn || true
fi
