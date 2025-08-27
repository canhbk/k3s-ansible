#!/bin/bash
set -euo pipefail

# PostgreSQL WAL Archiving MinIO Configuration Script

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Error handling function
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Check if required environment variables are set
: "${MINIO_ENDPOINT:?Need to set MINIO_ENDPOINT}"
: "${MINIO_ROOT_USER:?Need to set MINIO_ROOT_USER}"
: "${MINIO_ROOT_PASSWORD:?Need to set MINIO_ROOT_PASSWORD}"

# WAL Archiving Configuration Variables
BUCKET_NAME="postgres-wal"
POSTGRES_USER="postgres-user"
POSTGRES_USER_PASSWORD=$(openssl rand -base64 32)

# Check if MinIO client is installed
if ! command -v mc &> /dev/null; then
    error_exit "MinIO client (mc) is not installed. Please install it first."
fi

# Configure MinIO client alias
log "Configuring MinIO client alias..."
mc alias set minio "$MINIO_ENDPOINT" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" || \
    error_exit "Failed to configure MinIO client alias"

# Create bucket for PostgreSQL WAL archiving
log "Creating bucket '$BUCKET_NAME'..."
mc mb minio/"$BUCKET_NAME" || error_exit "Failed to create bucket"

# Create dedicated user for PostgreSQL WAL archiving
log "Creating user '$POSTGRES_USER'..."
mc admin user add minio "$POSTGRES_USER" "$POSTGRES_USER_PASSWORD" || \
    error_exit "Failed to create MinIO user"

# Create IAM policy for WAL archiving
log "Creating IAM policy for WAL archiving..."
mc admin policy create minio postgres-wal-policy - <<EOF || error_exit "Failed to create policy"
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::${BUCKET_NAME}/*",
                "arn:aws:s3:::${BUCKET_NAME}"
            ]
        }
    ]
}
EOF

# Attach policy to user
log "Attaching policy to user..."
mc admin policy attach minio postgres-wal-policy user="$POSTGRES_USER" || \
    error_exit "Failed to attach policy to user"

# Configure bucket lifecycle (optional: 30-day object expiration)
log "Configuring bucket lifecycle policy..."
mc ilm add minio/"$BUCKET_NAME" --expiration-days 30 || \
    log "Warning: Could not set lifecycle policy"

# Display configuration details
log "WAL Archiving MinIO Configuration Complete"
echo "-------------------------------------------"
echo "Bucket Name: $BUCKET_NAME"
echo "WAL Archive User: $POSTGRES_USER"
echo "WAL Archive User Password: $POSTGRES_USER_PASSWORD"
echo "MinIO Endpoint: $MINIO_ENDPOINT"
echo "-------------------------------------------"

# Note: Store credentials securely and do not print in production
log "IMPORTANT: Securely store the WAL archive user credentials"

exit 0