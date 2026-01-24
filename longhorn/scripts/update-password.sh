#!/bin/bash
# Script to update Longhorn basic auth password

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="longhorn-system"
SECRET_NAME="basic-auth"
USERNAME=""
PASSWORD=""
CLUSTER=""
GENERATE_PASSWORD=false

# Function to print colored output
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to show usage
usage() {
    cat << EOF
Usage: $0 -c CLUSTER [-u USERNAME] [-p PASSWORD] [-g]

Update Longhorn basic auth password for a specific cluster

Options:
    -c CLUSTER      Cluster name (required: dev, vn, eu, jp, sg, sg2, us, vn2)
    -u USERNAME     Username (default: admin)
    -p PASSWORD     New password (will prompt if not provided)
    -g              Generate a random secure password
    -h              Show this help message

Examples:
    $0 -c us                     # Update password for US cluster (will prompt)
    $0 -c dev -u admin -p newpass # Set specific password
    $0 -c vn -g                  # Generate random password for VN cluster

EOF
    exit 1
}

# Function to generate random password
generate_password() {
    # Generate a 16-character password with letters, numbers, and special characters
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-16
}

# Parse command line arguments
while getopts "c:u:p:gh" opt; do
    case ${opt} in
        c) CLUSTER=$OPTARG ;;
        u) USERNAME=$OPTARG ;;
        p) PASSWORD=$OPTARG ;;
        g) GENERATE_PASSWORD=true ;;
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

# Set default username if not provided
if [ -z "$USERNAME" ]; then
    USERNAME="admin"
    print_info "Using default username: admin"
fi

# Generate or prompt for password
if [ "$GENERATE_PASSWORD" = true ]; then
    PASSWORD=$(generate_password)
    print_info "Generated secure password: ${GREEN}$PASSWORD${NC}"
    print_warn "Save this password securely! It won't be shown again."
elif [ -z "$PASSWORD" ]; then
    # Prompt for password
    echo -n "Enter new password for user '$USERNAME': "
    read -s PASSWORD
    echo
    echo -n "Confirm password: "
    read -s PASSWORD_CONFIRM
    echo

    if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
        print_error "Passwords do not match"
        exit 1
    fi
fi

# Validate password is not empty
if [ -z "$PASSWORD" ]; then
    print_error "Password cannot be empty"
    exit 1
fi

# Switch to cluster context
print_info "Switching to cluster context: $CLUSTER"
if ! kubectl config use-context "$CLUSTER" >/dev/null 2>&1; then
    print_error "Failed to switch to cluster context: $CLUSTER"
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    print_error "Namespace $NAMESPACE does not exist in cluster $CLUSTER"
    print_error "Is Longhorn installed on this cluster?"
    exit 1
fi

# Check if htpasswd is available
if ! command -v htpasswd >/dev/null 2>&1; then
    print_error "htpasswd command not found. Please install apache2-utils (Debian/Ubuntu) or httpd-tools (RHEL/CentOS)"
    exit 1
fi

# Generate password hash
print_info "Generating password hash..."
HASH=$(htpasswd -nb "$USERNAME" "$PASSWORD" 2>/dev/null)
if [ $? -ne 0 ]; then
    print_error "Failed to generate password hash"
    exit 1
fi

# Check if secret exists
if kubectl -n "$NAMESPACE" get secret "$SECRET_NAME" >/dev/null 2>&1; then
    print_info "Updating existing secret: $SECRET_NAME"
    # Delete existing secret
    kubectl -n "$NAMESPACE" delete secret "$SECRET_NAME" >/dev/null 2>&1
else
    print_info "Creating new secret: $SECRET_NAME"
fi

# Create new secret
if kubectl -n "$NAMESPACE" create secret generic "$SECRET_NAME" --from-literal=users="$HASH"; then
    print_success "Password updated successfully for user '$USERNAME' in cluster '$CLUSTER'"

    # Restart Longhorn UI pod to ensure changes take effect
    print_info "Restarting Longhorn UI pod..."
    kubectl -n "$NAMESPACE" rollout restart deployment/longhorn-ui >/dev/null 2>&1 || true

    print_info "Access Longhorn UI at: https://${CLUSTER}.longhorn.canhnv.com"
    print_info "Username: $USERNAME"
    if [ "$GENERATE_PASSWORD" = true ]; then
        print_info "Password: $PASSWORD (save this securely!)"
    else
        print_info "Password: [your provided password]"
    fi
else
    print_error "Failed to create/update secret"
    exit 1
fi

# Verify the secret was created
if kubectl -n "$NAMESPACE" get secret "$SECRET_NAME" >/dev/null 2>&1; then
    print_success "Password update completed successfully!"
else
    print_error "Secret verification failed"
    exit 1
fi
