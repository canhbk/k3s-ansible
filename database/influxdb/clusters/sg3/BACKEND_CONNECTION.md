# Backend Connection to InfluxDB on sg3

## Quick Setup

### 1. Apply the Secret

```bash
kubectl config use-context sg3
kubectl apply -f database/influxdb/clusters/sg3/backend-influxdb-config.yaml
```

### 2. Verify Secret Creation

```bash
kubectl get secret backend-influxdb-config -n default -o yaml
```

### 3. Use in Your Backend Deployment

Add to your deployment manifest:

```yaml
envFrom:
- secretRef:
    name: backend-influxdb-config
```

## Connection Details

| Variable | Value |
|----------|-------|
| INFLUXDB_URL | `http://influxdb-influxdb2.influxdb.svc.cluster.local:8086` |
| INFLUXDB_TOKEN | `__REDACTED__` |
| INFLUXDB_ORG | `murror` |
| INFLUXDB_BUCKET | `murror_api_metrics` |

## Testing Connection

### From within a pod in the cluster:

```bash
# Create a test pod
kubectl run -it --rm test-influx --image=curlimages/curl --restart=Never -- sh

# Test connection
curl -i http://influxdb-influxdb2.influxdb.svc.cluster.local:8086/health
```

### Verify bucket exists:

```bash
# Port-forward to access InfluxDB locally
kubectl port-forward -n influxdb svc/influxdb-influxdb2 8086:8086

# In another terminal, check buckets
curl -H "Authorization: Token __REDACTED__" \
  http://localhost:8086/api/v2/buckets?org=murror
```

## Creating the Bucket (if needed)

If the `murror_api_metrics` bucket doesn't exist, create it:

```bash
# Via port-forward
kubectl port-forward -n influxdb svc/influxdb-influxdb2 8086:8086

# Create bucket
curl -X POST http://localhost:8086/api/v2/buckets \
  -H "Authorization: Token __REDACTED__" \
  -H "Content-Type: application/json" \
  -d '{
    "orgID": "get-from-org-list",
    "name": "murror_api_metrics",
    "retentionRules": [
      {
        "type": "expire",
        "everySeconds": 2592000
      }
    ]
  }'
```

## Troubleshooting

### Check if backend can resolve the service:

```bash
kubectl exec -it <your-backend-pod> -- nslookup influxdb-influxdb2.influxdb.svc.cluster.local
```

### Check if backend can connect:

```bash
kubectl exec -it <your-backend-pod> -- curl http://influxdb-influxdb2.influxdb.svc.cluster.local:8086/health
```

### View backend logs:

```bash
kubectl logs -f <your-backend-pod>
```

## Security Notes

- The admin token has full access - consider creating a scoped token for production
- Store tokens in Kubernetes Secrets, never in ConfigMaps or plain YAML
- Use RBAC to restrict access to the secret
- Consider using network policies to restrict pod-to-pod communication

## Next Steps

1. **Create the bucket** if it doesn't exist
2. **Apply the secret** to your namespace
3. **Update your deployment** to use the secret
4. **Test the connection** from your backend pod
5. **Monitor metrics** in InfluxDB UI at https://influxdb.sg3.k3s.canhnv.com
