#!/bin/bash
# Simple script to update Longhorn basic auth password using Docker

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
USERNAME="admin"

# Function to print colored output
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to show usage
usage() {
    cat << EOF
Usage: $0 CLUSTER [USERNAME]

Update Longhorn basic auth password for a specific cluster

Arguments:
    CLUSTER     Cluster name (required: dev, vn, eu, jp, sg, sg2, us, vn2)
    USERNAME    Username (optional, default: admin)

Examples:
    $0 us                  # Update password for admin user in US cluster
    $0 dev johndoe         # Update password for johndoe user in dev cluster

The script will prompt for the new password.

EOF
    exit 1
}

# Check arguments
if [ $# -lt 1 ]; then
    usage
fi

CLUSTER=$1
if [ $# -ge 2 ]; then
    USERNAME=$2
fi

# Check if cluster is valid
VALID_CLUSTERS=("dev" "vn" "eu" "jp" "sg" "sg2" "us" "vn2")
if [[ ! " ${VALID_CLUSTERS[@]} " =~ " ${CLUSTER} " ]]; then
    print_error "Invalid cluster: $CLUSTER"
    print_error "Valid clusters: ${VALID_CLUSTERS[*]}"
    exit 1
fi

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

# Generate password hash using Docker
print_info "Generating password hash..."
HASH=$(docker run --rm httpd:2.4-alpine htpasswd -nb "$USERNAME" "$PASSWORD" 2>/dev/null)
if [ $? -ne 0 ]; then
    print_error "Failed to generate password hash"
    print_error "Make sure Docker is running and accessible"
    exit 1
fi

# Update secret
print_info "Updating password for user '$USERNAME'..."

# Delete existing secret if it exists
kubectl -n "$NAMESPACE" delete secret "$SECRET_NAME" >/dev/null 2>&1 || true

# Create new secret
if kubectl -n "$NAMESPACE" create secret generic "$SECRET_NAME" --from-literal=users="$HASH"; then
    print_success "Password updated successfully!"
    
    # Restart Longhorn UI pod
    print_info "Restarting Longhorn UI pod..."
    kubectl -n "$NAMESPACE" rollout restart deployment/longhorn-ui >/dev/null 2>&1 || true
    
    echo
    print_success "Password update completed!"
    print_info "Access Longhorn UI at: https://${CLUSTER}.longhorn.canhnv.com"
    print_info "Username: $USERNAME"
    print_info "Password: [your new password]"
else
    print_error "Failed to update password"
    exit 1
fi