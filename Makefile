.PHONY: help bootstrap deploy destroy clean status test

CLUSTER_NAME := saga-platform
K3D_CONFIG := infra/bootstrap/k3d-config.yaml

help: ## show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

bootstrap: ## bootstrap the entire platform (cluster + infrastructure)
	@echo "🚀 Bootstrapping saga-commerce-platform..."
	@$(MAKE) create-cluster
	@$(MAKE) install-infra
	@echo "✅ Bootstrap complete!"

create-cluster: ## create k3d cluster
	@echo "📦 Creating k3d cluster..."
	k3d cluster create $(CLUSTER_NAME) --config $(K3D_CONFIG) || echo "Cluster already exists"
	@echo "⏳ Waiting for cluster to be ready..."
	kubectl wait --for=condition=Ready nodes --all --timeout=120s

install-infra: ## install infrastructure components using terraform
	@echo "🏗️  Installing infrastructure..."
	cd infra/terraform && terraform init
	cd infra/terraform && terraform apply -auto-approve
	@echo "⏳ Waiting for ArgoCD to be ready..."
	kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

deploy: docker-push-all ## build and push all images, then deploy all services via ArgoCD
	@echo "🚢 Deploying services..."
	kubectl apply -f infra/argocd/applications/

docker-push-all: ## Push all service images to local registry for k3d (host: localhost:5001, cluster: saga-registry:5000)
	@echo "🐳 Pushing all service images to localhost:5001 (mapped to saga-registry:5000 inside cluster)..."
	docker push localhost:5001/order-service:latest
	docker push localhost:5001/inventory-service:latest
	docker push localhost:5001/payment-service:latest
	docker push localhost:5001/notification-service:latest

status: ## check status of all components
	@echo "📊 Cluster Status:"
	@kubectl get nodes
	@echo "\n📊 Infrastructure Status:"
	@kubectl get pods -A
	@echo "\n📊 ArgoCD Applications:"
	@kubectl get applications -n argocd 2>/dev/null || echo "ArgoCD not yet installed"

destroy: ## destroy the entire platform
	@echo "💥 Destroying saga-commerce-platform..."
	k3d cluster delete $(CLUSTER_NAME) || echo "Cluster doesn't exist"
	@echo "🧹 Cleaning up terraform state..."
	cd infra/terraform && rm -rf .terraform .terraform.lock.hcl terraform.tfstate* || true
	@echo "✅ Destroy complete!"

clean: ## clean local build artifacts
	@echo "🧹 Cleaning build artifacts..."
	find . -type d -name "target" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name "build" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name "dist" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name "node_modules" -exec rm -rf {} + 2>/dev/null || true

test: ## run tests for all services
	@echo "🧪 Running tests..."
	@echo "Not yet implemented"
