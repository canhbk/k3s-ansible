# K3s Ansible Project Overview

## Purpose
This is an Ansible-based automation project for deploying and managing K3s Kubernetes clusters. K3s is a lightweight Kubernetes distribution designed for edge, IoT, and resource-constrained environments.

## Tech Stack
- **Infrastructure**: K3s Kubernetes clusters across multiple regions
- **Automation**: Ansible for deployment and management
- **OS Support**: Debian, Ubuntu, Raspberry Pi OS, RHEL Family, SUSE Family, ArchLinux
- **Architectures**: x64, arm64, armhf
- **Cluster Management**: Multiple production and development clusters (8 total)

## Cluster Fleet (8 Clusters)
- **Development**: dev (US) - https://154.26.131.23:6443
- **Production**: 
  - eu (Europe) - https://31.14.17.182:6443
  - jp (Asia-Pacific) - https://84.247.152.54:6443  
  - sg (Singapore Primary) - https://46.250.232.0:6443
  - sg2 (Singapore Secondary) - https://46.250.231.255:6443
  - us (North America) - https://65.49.60.35:6443
  - vn (Vietnam Primary) - https://vps22.canhnv.com:6443
  - vn2 (Vietnam Secondary) - https://163.61.73.78:6443

## Key Components
- **Application Stack**: PostgreSQL HA, Redis, RabbitMQ, MySQL, InfluxDB
- **Monitoring**: SigNoz, Prometheus, Grafana
- **Storage**: Longhorn distributed storage
- **Security**: Cert-Manager for TLS certificates
- **Management**: Rancher UI for cluster management

## Architecture
- **Control Nodes**: K3s server nodes with embedded etcd for HA
- **Worker Nodes**: K3s agent nodes for workloads
- **Storage**: Local-path (default) and Longhorn distributed storage
- **Networking**: Traefik ingress controller with automatic HTTPS
- **Load Balancing**: Multiple external IPs for LoadBalancer services