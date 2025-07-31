# Fix Cloudflare SSL/TLS Error for Grafana

## The Issue

You're getting an "ERR_SSL_VERSION_OR_CIPHER_MISMATCH" error when accessing Grafana through Cloudflare.

## Solution

### 1. Check Cloudflare SSL/TLS Settings

1. Log in to your Cloudflare dashboard
2. Select your domain (canhnv.com)
3. Go to **SSL/TLS** → **Overview**
4. Set the SSL/TLS encryption mode to **Full (strict)**
   - This is required because your cluster has a valid Let's Encrypt certificate

### 2. Check Cloudflare DNS Settings

Ensure your DNS record is set correctly:

- **Type**: A or CNAME
- **Name**: grafana.dev.k3s
- **Content**: Your cluster IP (154.26.131.23) or appropriate CNAME
- **Proxy status**: Should be **Proxied** (orange cloud)

### 3. Cloudflare SSL/TLS Edge Certificates

Go to **SSL/TLS** → **Edge Certificates** and ensure:

- **Always Use HTTPS**: ON
- **Minimum TLS Version**: TLS 1.2
- **TLS 1.3**: Enabled

### 4. Alternative: Bypass Cloudflare (for testing)

If you want to test without Cloudflare proxy:

1. In Cloudflare DNS settings, click on the orange cloud to make it grey (DNS only)
2. Wait a few minutes for DNS propagation
3. Try accessing <https://grafana.dev.k3s.canhnv.com> again

### 5. Direct Access (without domain)

You can also access Grafana using port-forwarding:

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Then access: <http://localhost:3000>

### Current Status

- ✅ Certificate is valid and properly issued
- ✅ Ingress is correctly configured
- ✅ Service is responding (tested with curl)
- ❌ Cloudflare SSL/TLS settings need adjustment

## Credentials

- **Username**: admin
- **Password**: prom-operator
