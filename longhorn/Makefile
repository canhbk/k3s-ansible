# Makefile for Longhorn multi-cluster deployment

.PHONY: help deploy-dev deploy-vn deploy-all dry-run-dev dry-run-vn status-dev status-vn uninstall-dev uninstall-vn

# Default target
help:
	@echo "Longhorn Multi-Cluster Deployment"
	@echo "================================="
	@echo ""
	@echo "Deployment targets:"
	@echo "  make deploy-dev      - Deploy Longhorn to dev cluster"
	@echo "  make deploy-vn       - Deploy Longhorn to vn cluster"
	@echo "  make deploy-all      - Deploy to all configured clusters"
	@echo ""
	@echo "Dry run targets:"
	@echo "  make dry-run-dev     - Dry run deployment for dev cluster"
	@echo "  make dry-run-vn      - Dry run deployment for vn cluster"
	@echo ""
	@echo "Status targets:"
	@echo "  make status-dev      - Check Longhorn status in dev cluster"
	@echo "  make status-vn       - Check Longhorn status in vn cluster"
	@echo ""
	@echo "Uninstall targets:"
	@echo "  make uninstall-dev   - Uninstall Longhorn from dev cluster"
	@echo "  make uninstall-vn    - Uninstall Longhorn from vn cluster"
	@echo ""
	@echo "Maintenance targets:"
	@echo "  make update-repo     - Update Helm repository"
	@echo "  make validate        - Validate all configuration files"

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

# Deploy to all clusters
deploy-all: deploy-dev deploy-vn
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