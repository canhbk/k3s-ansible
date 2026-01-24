#!/bin/bash
# Script to create basic auth secret for Longhorn
# This script reads credentials from .secrets.env file

set -euo pipefail

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Source secrets file
SECRETS_FILE="${BASE_DIR}/.secrets.env"
if [ ! -f "$SECRETS_FILE" ]; then
    echo "Error: Secrets file not found: $SECRETS_FILE"
    echo "Please create the file with LONGHORN_ADMIN_USERNAME and LONGHORN_ADMIN_PASSWORD"
    exit 1
fi

# Source the secrets (skip comments and empty lines)
source <(grep -E "^[^#].*=" "$SECRETS_FILE")

# Check required variables
if [ -z "${LONGHORN_ADMIN_USERNAME:-}" ] || [ -z "${LONGHORN_ADMIN_HASH:-}" ]; then
    echo "Error: LONGHORN_ADMIN_USERNAME and LONGHORN_ADMIN_HASH must be set in $SECRETS_FILE"
    exit 1
fi

# Create or update the secret
echo "Creating/updating basic-auth secret in longhorn-system namespace..."

kubectl -n longhorn-system create secret generic basic-auth \
    --from-literal=users="${LONGHORN_ADMIN_USERNAME}:${LONGHORN_ADMIN_HASH}" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "Basic auth secret created/updated successfully!"
echo "Username: ${LONGHORN_ADMIN_USERNAME}"
echo "Remember to change the default password!"