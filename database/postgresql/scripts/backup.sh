#!/bin/bash
# PostgreSQL Backup Script for CloudNative-PG
# This script helps create and manage PostgreSQL backups

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="postgres-db"
CLUSTER_NAME="postgresql-ha"
BACKUP_NAME=""
BACKUP_TYPE="on-demand"
TARGET_DATABASE=""

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

# Function to generate backup name
generate_backup_name() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    echo "backup-${CLUSTER_NAME}-${timestamp}"
}

# Function to create on-demand backup
create_backup() {
    local backup_name="${BACKUP_NAME:-$(generate_backup_name)}"
    
    print_info "Creating backup: $backup_name"
    
    # Create backup resource
    cat <<EOF | kubectl apply -f -
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: $backup_name
  namespace: $NAMESPACE
spec:
  cluster:
    name: $CLUSTER_NAME
EOF
    
    print_info "Backup initiated. Monitoring progress..."
    
    # Wait for backup to complete
    local max_attempts=60
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        local phase=$(kubectl get backup "$backup_name" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "pending")
        
        case $phase in
            "completed")
                print_info "Backup completed successfully!"
                show_backup_details "$backup_name"
                return 0
                ;;
            "failed")
                print_error "Backup failed!"
                kubectl describe backup "$backup_name" -n "$NAMESPACE"
                return 1
                ;;
            *)
                echo -n "."
                sleep 5
                ((attempt++))
                ;;
        esac
    done
    
    print_warning "Backup is taking longer than expected. Check status manually."
    return 1
}

# Function to list backups
list_backups() {
    print_info "Listing backups for cluster: $CLUSTER_NAME"
    
    kubectl get backups -n "$NAMESPACE" -l cnpg.io/cluster="$CLUSTER_NAME" \
        -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,STARTED:.status.startedAt,COMPLETED:.status.stoppedAt
}

# Function to show backup details
show_backup_details() {
    local backup_name="$1"
    
    print_info "Backup details for: $backup_name"
    kubectl describe backup "$backup_name" -n "$NAMESPACE"
}

# Function to restore from backup
restore_backup() {
    local backup_name="$1"
    local new_cluster_name="${2:-${CLUSTER_NAME}-restored}"
    
    print_info "Restoring from backup: $backup_name"
    print_warning "This will create a new cluster: $new_cluster_name"
    
    # Get the original cluster configuration
    local storage_size=$(kubectl get cluster "$CLUSTER_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.storage.size}')
    local storage_class=$(kubectl get cluster "$CLUSTER_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.storage.storageClass}')
    local instances=$(kubectl get cluster "$CLUSTER_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.instances}')
    
    # Create restore cluster
    cat <<EOF | kubectl apply -f -
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: $new_cluster_name
  namespace: $NAMESPACE
spec:
  instances: $instances
  
  bootstrap:
    recovery:
      backup:
        name: $backup_name
  
  storage:
    size: $storage_size
    storageClass: $storage_class
EOF
    
    print_info "Restore initiated. Monitor progress with:"
    echo "kubectl get cluster $new_cluster_name -n $NAMESPACE"
    echo "kubectl get pods -n $NAMESPACE -l cnpg.io/cluster=$new_cluster_name"
}

# Function to export database
export_database() {
    local database="${TARGET_DATABASE:-default}"
    local output_file="dump-${CLUSTER_NAME}-${database}-$(date +%Y%m%d-%H%M%S).sql"
    
    print_info "Exporting database: $database to $output_file"
    
    # Get primary pod
    local primary_pod=$(kubectl get pods -n "$NAMESPACE" \
        -l cnpg.io/cluster="$CLUSTER_NAME",cnpg.io/instanceRole=primary \
        -o jsonpath='{.items[0].metadata.name}')
    
    if [[ -z "$primary_pod" ]]; then
        print_error "Could not find primary pod for cluster: $CLUSTER_NAME"
        return 1
    fi
    
    # Export database
    kubectl exec -n "$NAMESPACE" "$primary_pod" -- \
        pg_dump -U postgres -d "$database" > "$output_file"
    
    print_info "Database exported to: $output_file"
    print_info "File size: $(du -h "$output_file" | cut -f1)"
}

# Function to configure scheduled backups
configure_scheduled_backup() {
    print_info "Configuring scheduled backup for cluster: $CLUSTER_NAME"
    
    cat <<EOF
To configure scheduled backups, add the following to your cluster configuration:

spec:
  backup:
    retentionPolicy: "30d"
    target: "s3://your-bucket/backups"
    
    # For S3-compatible storage
    s3Credentials:
      accessKeyId:
        name: backup-credentials
        key: ACCESS_KEY_ID
      secretAccessKey:
        name: backup-credentials
        key: SECRET_ACCESS_KEY
    
    # Schedule (cron format)
    schedule: "0 2 * * *"  # Daily at 2 AM

Remember to create the credentials secret:

kubectl create secret generic backup-credentials \\
  --from-literal=ACCESS_KEY_ID=your-access-key \\
  --from-literal=SECRET_ACCESS_KEY=your-secret-key \\
  -n $NAMESPACE
EOF
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND

Manage PostgreSQL backups for CloudNative-PG clusters.

Commands:
    create              Create an on-demand backup
    list                List all backups
    show BACKUP_NAME    Show details of a specific backup
    restore BACKUP_NAME Restore from a backup
    export              Export database to SQL file
    schedule            Show scheduled backup configuration

Options:
    -n, --namespace NAMESPACE      Kubernetes namespace (default: postgres-db)
    -c, --cluster CLUSTER_NAME     Cluster name (default: postgresql-ha)
    -b, --backup-name NAME         Backup name (auto-generated if not provided)
    -d, --database DATABASE        Database name for export (default: default)
    -h, --help                     Show this help message

Examples:
    $0 create                          Create a backup with auto-generated name
    $0 -b my-backup create            Create a backup with custom name
    $0 list                           List all backups
    $0 show backup-20240115-120000    Show backup details
    $0 restore backup-20240115-120000 Restore from backup
    $0 -d mydb export                 Export database to SQL file

EOF
}

# Parse command line arguments
COMMAND=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -c|--cluster)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        -b|--backup-name)
            BACKUP_NAME="$2"
            shift 2
            ;;
        -d|--database)
            TARGET_DATABASE="$2"
            shift 2
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
            COMMAND="$1"
            shift
            break
            ;;
    esac
done

# Check prerequisites
if ! command_exists kubectl; then
    print_error "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Execute command
case $COMMAND in
    create)
        create_backup
        ;;
    list)
        list_backups
        ;;
    show)
        if [[ -z "$1" ]]; then
            print_error "Backup name required for show command"
            exit 1
        fi
        show_backup_details "$1"
        ;;
    restore)
        if [[ -z "$1" ]]; then
            print_error "Backup name required for restore command"
            exit 1
        fi
        restore_backup "$1" "$2"
        ;;
    export)
        export_database
        ;;
    schedule)
        configure_scheduled_backup
        ;;
    *)
        print_error "Invalid command: $COMMAND"
        usage
        exit 1
        ;;
esac