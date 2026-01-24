#!/bin/bash
# Verify WAL archiving is working

# Get MinIO secret key
MINIO_SECRET_KEY="$(kubectl get secret postgresql-minio-credentials -n postgres-db -o jsonpath='{.data.MINIO_SECRET_KEY}' | base64 -d)"

# Create a temporary MinIO client pod
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: minio-client-verify
  namespace: postgres-db
spec:
  containers:
  - name: mc
    image: minio/mc:latest
    command: ["sleep", "300"]
  restartPolicy: Never
EOF

# Wait for pod to be ready
echo "Waiting for MinIO client pod to be ready..."
kubectl wait --for=condition=Ready pod/minio-client-verify -n postgres-db --timeout=60s

# Configure MinIO client
echo "Configuring MinIO client..."
kubectl exec -n postgres-db minio-client-verify -- mc alias set myminio http://64.71.161.44:9000 postgres-user "$MINIO_SECRET_KEY"

# List WAL files
echo "Listing WAL archive files in MinIO:"
kubectl exec -n postgres-db minio-client-verify -- mc ls -r myminio/postgres-wal/pgvector-vn/

# Show disk usage
echo -e "\nShowing disk usage for WAL archives:"
kubectl exec -n postgres-db minio-client-verify -- mc du myminio/postgres-wal/pgvector-vn/

# Clean up pod
kubectl delete pod minio-client-verify -n postgres-db

echo -e "\nDone!"