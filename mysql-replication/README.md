# MySQL Setup Guide

This guide walks you through setting up a production MySQL instance on Kubernetes using Helm and the Bitnami MySQL chart.

## Prerequisites

Ensure you have kubectl and helm installed and configured to access your Kubernetes cluster.

## Installation Steps

### 1. Add the Bitnami Helm Repository

First, add the Bitnami repository to your Helm configuration:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### 2. Create Database Credentials

Create a Kubernetes secret to store your MySQL passwords securely:

```bash
kubectl create secret generic my-mysql-creds \
  --namespace database \
  --from-literal=mysql-root-password='s3cureRootP@ss' \
  --from-literal=mysql-replication-password='s3cureReplP@ss' \
  --from-literal=mysql-password='s3cureAppP@ss'
```

**Security Note**: Replace the example passwords with strong, unique passwords for your production environment.

### 3. Deploy MySQL

Install MySQL using Helm with your custom configuration:

```bash
helm install mysql-prod bitnami/mysql \
  --namespace database --create-namespace \
  -f values-prod.yaml
```

To upgrade an existing installation:

```bash
helm upgrade --install mysql-prod bitnami/mysql \
  --namespace database \
  -f values-prod.yaml
```

## Accessing Your Database

### Retrieve Administrator Credentials

Get the root password from the secret:

```bash
echo "Username: root"
MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace database my-mysql-creds -o jsonpath="{.data.mysql-root-password}" | base64 -d)
echo "Password: $MYSQL_ROOT_PASSWORD"
```

### Connect to MySQL

#### Method 1: Using a Temporary Client Pod

Run a temporary MySQL client pod:

```bash
kubectl run mysql-prod-client --rm --tty -i --restart='Never' \
  --image docker.io/bitnami/mysql:9.3.0-debian-12-r2 \
  --namespace database \
  --env MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
  --command -- bash
```

#### Method 2: Direct Connection Commands

Once inside the client pod, connect to different services:

**Primary Service (Read/Write)**:

```bash
mysql -h mysql-prod-primary.database.svc.cluster.local -uroot -p"$MYSQL_ROOT_PASSWORD"
```

**Secondary Service (Read-Only)**:

```bash
mysql -h mysql-prod-secondary.database.svc.cluster.local -uroot -p"$MYSQL_ROOT_PASSWORD"
```

## Database Verification

### Testing Replication

Follow these steps to verify that your MySQL replication is working correctly.

#### Step 1: Test on Primary Database

Connect to your primary MySQL instance and create test data:

```sql
-- Create a test database and table
CREATE DATABASE IF NOT EXISTS replication_test;
USE replication_test;

CREATE TABLE IF NOT EXISTS items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO items (name) VALUES ('Apple'), ('Banana'), ('Cherry');

-- Verify the data was inserted
SELECT * FROM items\G
```

#### Step 2: Verify on Replica

Wait a few seconds for replication to sync, then connect to your replica and verify:

```sql
USE replication_test;

-- Check if the data replicated successfully
SELECT * FROM items\G

-- Check replication status
SHOW REPLICA STATUS\G
```

The `SHOW REPLICA STATUS\G` command will display important replication metrics including lag time and any errors.

#### Step 3: Cleanup (Optional)

Remove the test database when finished:

```sql
DROP DATABASE replication_test;
```

## Troubleshooting

If replication isn't working:

1. Check the replica status for errors: `SHOW REPLICA STATUS\G`
2. Verify network connectivity between primary and replica
3. Ensure replication credentials are correct
4. Check MySQL error logs in the pod logs: `kubectl logs -n database <pod-name>`

## Next Steps

- Configure monitoring and alerting for your MySQL instance
- Set up regular backups
- Review and optimize your `values-prod.yaml` configuration
- Consider implementing connection pooling for your applications

## Security Considerations

- Regularly rotate database passwords
- Use network policies to restrict database access
- Enable MySQL audit logging if required
- Consider using encrypted connections (TLS/SSL)
