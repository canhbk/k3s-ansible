# Makefile for Longhorn multi-cluster deployment

.PHONY: help deploy-dev deploy-vn deploy-us deploy-eu deploy-all dry-run-dev dry-run-vn dry-run-us dry-run-eu status-dev status-vn status-us status-eu uninstall-dev uninstall-vn uninstall-us uninstall-eu

# Default target
help:
	@echo "Longhorn Multi-Cluster Deployment"
	@echo "================================="
	@echo ""
	@echo "Deployment targets:"
	@echo "  make deploy-dev      - Deploy Longhorn to dev cluster"
	@echo "  make deploy-vn       - Deploy Longhorn to vn cluster"
	@echo "  make deploy-us       - Deploy Longhorn to us cluster"
	@echo "  make deploy-eu       - Deploy Longhorn to eu cluster"
	@echo "  make deploy-all      - Deploy to all configured clusters"
	@echo ""
	@echo "Dry run targets:"
	@echo "  make dry-run-dev     - Dry run deployment for dev cluster"
	@echo "  make dry-run-vn      - Dry run deployment for vn cluster"
	@echo "  make dry-run-us      - Dry run deployment for us cluster"
	@echo "  make dry-run-eu      - Dry run deployment for eu cluster"
	@echo ""
	@echo "Status targets:"
	@echo "  make status-dev      - Check Longhorn status in dev cluster"
	@echo "  make status-vn       - Check Longhorn status in vn cluster"
	@echo "  make status-us       - Check Longhorn status in us cluster"
	@echo "  make status-eu       - Check Longhorn status in eu cluster"
	@echo ""
	@echo "Uninstall targets:"
	@echo "  make uninstall-dev   - Uninstall Longhorn from dev cluster"
	@echo "  make uninstall-vn    - Uninstall Longhorn from vn cluster"
	@echo "  make uninstall-us    - Uninstall Longhorn from us cluster"
	@echo "  make uninstall-eu    - Uninstall Longhorn from eu cluster"
	@echo ""
	@echo "Maintenance targets:"
	@echo "  make update-repo     - Update Helm repository"
	@echo "  make validate        - Validate all configuration files"
	@echo "  make install-prereq  - Install Longhorn prerequisites on current cluster"

# Variables
NAMESPACE := longhorn-system
HELM_RELEASE := longhorn
CHART_VERSION := 1.9.1

# Update Helm repository
update-repo:
	@echo "Updating Longhorn Helm repository..."
	@helm repo add longhorn https://charts.longhorn.io
	@helm repo update

# Validate configuration files
validate:
	@echo "Validating configuration files..."
	@echo "Checking base values..."
	@yq eval . base/values-base.yaml > /dev/null && echo "✓ base/values-base.yaml is valid" || echo "✗ base/values-base.yaml is invalid"
	@echo "Checking cluster values..."
	@for cluster in dev vn eu jp sg sg2 us vn2; do \
		if [ -f "clusters/$$cluster/values.yaml" ]; then \
			yq eval . clusters/$$cluster/values.yaml > /dev/null && echo "✓ clusters/$$cluster/values.yaml is valid" || echo "✗ clusters/$$cluster/values.yaml is invalid"; \
		fi; \
	done

# Deploy to dev cluster
deploy-dev: update-repo
	@echo "Deploying Longhorn to dev cluster..."
	@./scripts/deploy.sh -c dev -v $(CHART_VERSION)

# Deploy to vn cluster
deploy-vn: update-repo
	@echo "Deploying Longhorn to vn cluster..."
	@./scripts/deploy.sh -c vn -v $(CHART_VERSION)

# Deploy to us cluster
deploy-us: update-repo
	@echo "Deploying Longhorn to us cluster..."
	@./scripts/deploy.sh -c us -v $(CHART_VERSION)

# Deploy to eu cluster
deploy-eu: update-repo
	@echo "Deploying Longhorn to eu cluster..."
	@./scripts/deploy.sh -c eu -v $(CHART_VERSION)

# Deploy to all clusters
deploy-all: deploy-dev deploy-vn deploy-us deploy-eu
	@echo "Deployment to all clusters completed"

# Dry run for dev cluster
dry-run-dev:
	@echo "Running dry-run for dev cluster..."
	@./scripts/deploy.sh -c dev -v $(CHART_VERSION) -d

# Dry run for vn cluster
dry-run-vn:
	@echo "Running dry-run for vn cluster..."
	@./scripts/deploy.sh -c vn -v $(CHART_VERSION) -d

# Dry run for us cluster
dry-run-us:
	@echo "Running dry-run for us cluster..."
	@./scripts/deploy.sh -c us -v $(CHART_VERSION) -d

# Dry run for eu cluster
dry-run-eu:
	@echo "Running dry-run for eu cluster..."
	@./scripts/deploy.sh -c eu -v $(CHART_VERSION) -d

# Check status for dev cluster
status-dev:
	@echo "Checking Longhorn status in dev cluster..."
	@kubectl config use-context dev
	@echo "\n=== Longhorn Pods ==="
	@kubectl -n $(NAMESPACE) get pods
	@echo "\n=== Storage Classes ==="
	@kubectl get storageclass | grep longhorn || echo "No Longhorn storage classes found"
	@echo "\n=== Persistent Volumes ==="
	@kubectl get pv | grep longhorn || echo "No Longhorn volumes found"
	@echo "\n=== Ingress ==="
	@kubectl -n $(NAMESPACE) get ingress

# Check status for vn cluster
status-vn:
	@echo "Checking Longhorn status in vn cluster..."
	@kubectl config use-context vn
	@echo "\n=== Longhorn Pods ==="
	@kubectl -n $(NAMESPACE) get pods
	@echo "\n=== Storage Classes ==="
	@kubectl get storageclass | grep longhorn || echo "No Longhorn storage classes found"
	@echo "\n=== Persistent Volumes ==="
	@kubectl get pv | grep longhorn || echo "No Longhorn volumes found"
	@echo "\n=== Ingress ==="
	@kubectl -n $(NAMESPACE) get ingress

# Check status for us cluster
status-us:
	@echo "Checking Longhorn status in us cluster..."
	@kubectl config use-context us
	@echo "\n=== Longhorn Pods ==="
	@kubectl -n $(NAMESPACE) get pods
	@echo "\n=== Storage Classes ==="
	@kubectl get storageclass | grep longhorn || echo "No Longhorn storage classes found"
	@echo "\n=== Persistent Volumes ==="
	@kubectl get pv | grep longhorn || echo "No Longhorn volumes found"
	@echo "\n=== Ingress ==="
	@kubectl -n $(NAMESPACE) get ingress

# Check status for eu cluster
status-eu:
	@echo "Checking Longhorn status in eu cluster..."
	@kubectl config use-context eu
	@echo "\n=== Longhorn Pods ==="
	@kubectl -n $(NAMESPACE) get pods
	@echo "\n=== Storage Classes ==="
	@kubectl get storageclass | grep longhorn || echo "No Longhorn storage classes found"
	@echo "\n=== Persistent Volumes ==="
	@kubectl get pv | grep longhorn || echo "No Longhorn volumes found"
	@echo "\n=== Ingress ==="
	@kubectl -n $(NAMESPACE) get ingress

# Uninstall from dev cluster
uninstall-dev:
	@echo "WARNING: This will uninstall Longhorn from dev cluster!"
	@echo "Press Ctrl+C to cancel, or Enter to continue..."
	@read confirm
	@kubectl config use-context dev
	@helm uninstall $(HELM_RELEASE) -n $(NAMESPACE)
	@kubectl delete -f base/storageclass-base.yaml || true
	@kubectl delete -f clusters/dev/ingress.yaml || true
	@echo "Longhorn uninstalled from dev cluster"

# Uninstall from vn cluster
uninstall-vn:
	@echo "WARNING: This will uninstall Longhorn from vn cluster!"
	@echo "Press Ctrl+C to cancel, or Enter to continue..."
	@read confirm
	@kubectl config use-context vn
	@helm uninstall $(HELM_RELEASE) -n $(NAMESPACE)
	@kubectl delete -f base/storageclass-base.yaml || true
	@kubectl delete -f clusters/vn/ingress.yaml || true
	@echo "Longhorn uninstalled from vn cluster"

# Uninstall from us cluster
uninstall-us:
	@echo "WARNING: This will uninstall Longhorn from us cluster!"
	@echo "Press Ctrl+C to cancel, or Enter to continue..."
	@read confirm
	@kubectl config use-context us
	@helm uninstall $(HELM_RELEASE) -n $(NAMESPACE)
	@kubectl delete -f clusters/us/storageclass.yaml || true
	@kubectl delete -f clusters/us/ingress.yaml || true
	@echo "Longhorn uninstalled from us cluster"

# Uninstall from eu cluster
uninstall-eu:
	@echo "WARNING: This will uninstall Longhorn from eu cluster!"
	@echo "Press Ctrl+C to cancel, or Enter to continue..."
	@read confirm
	@kubectl config use-context eu
	@helm uninstall $(HELM_RELEASE) -n $(NAMESPACE)
	@kubectl delete -f clusters/eu/storageclass.yaml || true
	@kubectl delete -f clusters/eu/ingress.yaml || true
	@echo "Longhorn uninstalled from eu cluster"

# Install prerequisites
install-prereq:
	@echo "Installing Longhorn prerequisites on current cluster..."
	@echo "Current context: $$(kubectl config current-context)"
	@echo ""
	@echo "Installing NFS utilities..."
	@kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v$(CHART_VERSION)/deploy/prerequisite/longhorn-nfs-installation.yaml
	@echo ""
	@echo "Installing iSCSI utilities..."
	@kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v$(CHART_VERSION)/deploy/prerequisite/longhorn-iscsi-installation.yaml
	@echo ""
	@echo "Creating DaemonSet to load dm_crypt module..."
	@kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: enable-dm-crypt
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: enable-dm-crypt
  template:
    metadata:
      labels:
        name: enable-dm-crypt
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: enable-dm-crypt
        image: alpine
        command: ["nsenter", "--target", "1", "--mount", "--uts", "--ipc", "--net", "--pid", "--", "sh", "-c", "modprobe dm_crypt && echo 'dm_crypt module loaded' && sleep infinity"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: host-modules
          mountPath: /lib/modules
          readOnly: true
      volumes:
      - name: host-modules
        hostPath:
          path: /lib/modules
EOF
	@echo ""
	@echo "Prerequisites installation started. Wait for all pods to be ready:"
	@echo "  kubectl get pods -n longhorn-system | grep -E 'nfs-installation|iscsi-installation'"
	@echo "  kubectl get pods -n kube-system | grep dm-crypt"