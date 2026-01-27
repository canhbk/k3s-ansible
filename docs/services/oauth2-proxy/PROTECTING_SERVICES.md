# Protecting Services with oauth2-proxy

## Quick Start

Add this annotation to your Ingress:

```yaml
annotations:
  traefik.ingress.kubernetes.io/router.middlewares: oauth2-proxy-oauth2-proxy-chain@kubernetescrd
```

## Complete Example

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: my-namespace
  annotations:
    cert-manager.io/cluster-issuer: "canhnv-com-prod"
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.middlewares: oauth2-proxy-oauth2-proxy-chain@kubernetescrd
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - my-app.sg3.canhnv.com
      secretName: my-app-tls
  rules:
    - host: my-app.sg3.canhnv.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

## Available Headers

After authentication, these headers are passed to your application:

| Header | Description |
|--------|-------------|
| X-Auth-Request-User | Username |
| X-Auth-Request-Email | User's email |
| X-Auth-Request-Preferred-Username | Preferred username |
| X-Auth-Request-Groups | User's groups |
| X-Auth-Request-Access-Token | OAuth access token |
| Authorization | Bearer token |

## Reading Headers

### Node.js/Express

```javascript
app.get('/api/user', (req, res) => {
  const email = req.headers['x-auth-request-email'];
  res.json({ email });
});
```

### Python/Flask

```python
@app.route('/api/user')
def get_user():
    email = request.headers.get('X-Auth-Request-Email')
    return jsonify({'email': email})
```

## Middleware Reference

| Middleware | Purpose |
|------------|---------|
| oauth2-proxy-auth | Auth verification only |
| oauth2-proxy-errors | Redirects 401 to sign-in |
| oauth2-proxy-chain | Complete auth flow (recommended) |

**Annotation format:** `<namespace>-<middleware-name>@kubernetescrd`

## Troubleshooting

### User sees 401 instead of login

Use the chain middleware, not auth:

```yaml
# Correct
oauth2-proxy-oauth2-proxy-chain@kubernetescrd

# Wrong
oauth2-proxy-oauth2-proxy-auth@kubernetescrd
```

### Cookies not set

Check cookie domain matches service domain:

```yaml
extraArgs:
  cookie-domain: ".canhnv.com"
```
