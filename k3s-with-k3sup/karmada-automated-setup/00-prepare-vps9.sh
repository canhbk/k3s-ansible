#!/bin/bash
# Script to prepare vps9 for Karmada setup
# Run this on vps9 before transferring files

set -e

echo "=== Preparing vps9 for Karmada Setup ==="
echo ""

# Create directory structure
echo "Creating directory structure..."
mkdir -p /root/karmada-setup/{configs,scripts,backups,policies}

echo "✓ Directory structure created:"
tree /root/karmada-setup/ 2>/dev/null || ls -la /root/karmada-setup/

echo ""
echo "✓ vps9 is ready!"
echo ""
echo "Now you can transfer files:"
echo "  scp ~/karmada-kubeconfigs/kubeconfig-* root@46.250.232.0:/root/karmada-setup/configs/"
echo "  scp 02-setup-karmada-host.sh root@46.250.232.0:/root/karmada-setup/scripts/"
echo "  scp 03-join-clusters.sh root@46.250.232.0:/root/karmada-setup/scripts/"
echo "  scp 04-test-deployment-with-info.sh root@46.250.232.0:/root/karmada-setup/scripts/"