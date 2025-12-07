# RabbitMQ Deployment - US Cluster

## Overview

RabbitMQ has been deployed to the US cluster as a message broker for asynchronous communication between services.

## Deployment Details

- **Namespace**: `rabbitmq`
- **Helm Chart**: `bitnami/rabbitmq` (version 16.0.14)
- **App Version**: 4.1.3
- **Storage Class**: `longhorn-replicated` (5Gi)
- **Replicas**: 1

## Access Information

### Internal Access (Within Cluster)

- **Service**: `rabbitmq.rabbitmq.svc.cluster.local`
- **AMQP Port**: 5672
- **Management Port**: 15672

### External Access

#### LoadBalancer Service
- **External IPs**: 64.71.161.44, 65.49.60.35
- **AMQP Port**: 5672 (NodePort: 30000)
- **Management Port**: 15672

#### Management UI (via Ingress)
- **URL**: https://us.rabbitmq.canhnv.com
- **Username**: `rabbitmq`
- **Password**: `US_RabbitMQ_Secure_Pass_2024`

## Service Endpoints

```bash
# AMQP Connection String
amqp://rabbitmq:US_RabbitMQ_Secure_Pass_2024@64.71.161.44:5672/

# Management UI
https://us.rabbitmq.canhnv.com
```

## Enabled Plugins

- `rabbitmq_management` - Web-based management interface
- `rabbitmq_prometheus` - Prometheus metrics exporter
- `rabbitmq_shovel` - Data replication between brokers
- `rabbitmq_shovel_management` - Shovel management UI

## Configuration Highlights

- **Memory High Watermark**: 60% of available memory
- **Disk Free Limit**: 1GB minimum
- **Prometheus Metrics Port**: 15692
- **TLS**: Enabled via cert-manager with Let's Encrypt

## Deployment Commands

```bash
# Deploy RabbitMQ
helm install rabbitmq oci://registry-1.docker.io/bitnamicharts/rabbitmq \
  --values /Users/canhnv/development/canhnv/k3s-ansible/rabbitmq/clusters/us/values.yaml \
  --namespace rabbitmq

# Upgrade RabbitMQ
helm upgrade rabbitmq oci://registry-1.docker.io/bitnamicharts/rabbitmq \
  --values /Users/canhnv/development/canhnv/k3s-ansible/rabbitmq/clusters/us/values.yaml \
  --namespace rabbitmq
```

## Monitoring

RabbitMQ exposes Prometheus metrics on port 15692. These can be scraped by your monitoring stack.

## Backup Considerations

The RabbitMQ data is stored on a Longhorn persistent volume with 2 replicas for redundancy. Consider implementing regular backups of:
- Queue definitions
- Exchange configurations
- User permissions
- Virtual hosts

## Troubleshooting

```bash
# Check pod status
kubectl get pods -n rabbitmq

# View logs
kubectl logs -n rabbitmq rabbitmq-0

# Access RabbitMQ CLI
kubectl exec -it -n rabbitmq rabbitmq-0 -- rabbitmqctl status

# List queues
kubectl exec -it -n rabbitmq rabbitmq-0 -- rabbitmqctl list_queues

# List users
kubectl exec -it -n rabbitmq rabbitmq-0 -- rabbitmqctl list_users
```

## Security Notes

- The default password has been set in the values.yaml file
- Consider rotating credentials periodically
- TLS is enabled for the management interface via Traefik ingress
- The LoadBalancer service exposes AMQP port directly - ensure firewall rules are configured appropriately

## Last Updated

August 25, 2025