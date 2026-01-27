# Cloudflare DNS Management

## Token Location

The Cloudflare API token for `canhnv.com` is stored at:
```
~/.config/cloudflare/canhnv-com-token
```

## Zone Information

| Domain | Zone ID |
|--------|---------|
| canhnv.com | `4e69df1006f193f8cbcd2e1a861ded23` |

## Usage Examples

### Set up environment
```bash
export CF_TOKEN=$(cat ~/.config/cloudflare/canhnv-com-token)
export ZONE_ID="4e69df1006f193f8cbcd2e1a861ded23"
```

### List all DNS records
```bash
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -H "Content-Type: application/json" | jq '.result[] | {name, type, content}'
```

### Create A record
```bash
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "A",
    "name": "subdomain",
    "content": "1.2.3.4",
    "ttl": 1,
    "proxied": false
  }'
```

### Delete DNS record
```bash
# First get the record ID
RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=subdomain.canhnv.com" \
  -H "Authorization: Bearer $CF_TOKEN" | jq -r '.result[0].id')

# Then delete
curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $CF_TOKEN"
```

### Update DNS record
```bash
RECORD_ID="your-record-id"
curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "A",
    "name": "subdomain",
    "content": "5.6.7.8",
    "ttl": 1,
    "proxied": false
  }'
```

### Verify DNS propagation
```bash
dig +short subdomain.canhnv.com @1.1.1.1
```

## Current DNS Records

### Numerology Alpha

| Subdomain | Type | Target IP | Cluster |
|-----------|------|-----------|---------|
| api-alpha.numerology | A | 15.235.197.12 | SG3 |
| web-alpha.numerology | A | 15.235.197.12 | SG3 |
| app-alpha.numerology | A | 15.235.197.12 | SG3 |
| admin-alpha.numerology | A | 15.235.197.12 | SG3 |

### Clotheshop Alpha

| Subdomain | Type | Target IP | Cluster |
|-----------|------|-----------|---------|
| api-alpha.clotheshop | A | 15.235.197.12 | SG3 |
| web-alpha.clotheshop | A | 15.235.197.12 | SG3 |
| admin-alpha.clotheshop | A | 15.235.197.12 | SG3 |

### Kong API Gateway (SG3)

| Subdomain | Type | Target IP | Cluster | Purpose |
|-----------|------|-----------|---------|---------|
| kong.sg3 | A | 15.235.197.12 | SG3 | Kong Proxy |
| api.sg3 | A | 15.235.197.12 | SG3 | Kong Proxy (Alias) |
| kong-admin.sg3 | A | 15.235.197.12 | SG3 | Kong Admin API |
| kong-manager.sg3 | A | 15.235.197.12 | SG3 | Kong Manager GUI |

## Token Permissions

The token requires:
- Zone:DNS:Edit permission for canhnv.com
