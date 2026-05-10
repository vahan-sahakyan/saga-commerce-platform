.PHONY: help bootstrap deploy destroy clean status test \
        build-order build-inventory build-payment build-notification build-all \
        dev-order dev-inventory dev-payment dev-notification dev-all \
        restart-order restart-inventory restart-payment restart-notification \
        logs-order logs-inventory logs-payment logs-notification \
        pf-grafana pf-prometheus pf-jaeger pf-redpanda pf-order pf-obs pf-all

CLUSTER_NAME  := saga-platform
K3D_CONFIG    := infra/bootstrap/k3d-config.yaml
REGISTRY      := saga-registry:5000
SERVICES_NS   := services

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

# ─── Build targets ────────────────────────────────────────────────────────────

build-order: ## Build order-service image (runs mvn package first)
	@echo "🔨 Building order-service..."
	cd services/order-service && mvn package -DskipTests -q
	docker build -t $(REGISTRY)/order-service:latest services/order-service/

build-inventory: ## Build inventory-service image
	@echo "🔨 Building inventory-service..."
	docker build -t $(REGISTRY)/inventory-service:latest services/inventory-service/

build-payment: ## Build payment-service image
	@echo "🔨 Building payment-service..."
	docker build -t $(REGISTRY)/payment-service:latest services/payment-service/

build-notification: ## Build notification-service image
	@echo "🔨 Building notification-service..."
	docker build -t $(REGISTRY)/notification-service:latest services/notification-service/

build-all: build-order build-inventory build-payment build-notification ## Build all service images

# ─── Dev targets (build → import into k3d → rollout restart) ─────────────────
# Uses k3d image import to bypass IfNotPresent caching issues.

dev-order: build-order ## Build, import into k3d, and restart order-service
	@echo "📦 Importing order-service into cluster..."
	k3d image import $(REGISTRY)/order-service:latest -c $(CLUSTER_NAME)
	kubectl rollout restart deployment/order-service -n $(SERVICES_NS)
	kubectl rollout status deployment/order-service -n $(SERVICES_NS) --timeout=120s

dev-inventory: build-inventory ## Build, import into k3d, and restart inventory-service
	@echo "📦 Importing inventory-service into cluster..."
	k3d image import $(REGISTRY)/inventory-service:latest -c $(CLUSTER_NAME)
	kubectl rollout restart deployment/inventory-service -n $(SERVICES_NS)
	kubectl rollout status deployment/inventory-service -n $(SERVICES_NS) --timeout=120s

dev-payment: build-payment ## Build, import into k3d, and restart payment-service
	@echo "📦 Importing payment-service into cluster..."
	k3d image import $(REGISTRY)/payment-service:latest -c $(CLUSTER_NAME)
	kubectl rollout restart deployment/payment-service -n $(SERVICES_NS)
	kubectl rollout status deployment/payment-service -n $(SERVICES_NS) --timeout=120s

dev-notification: build-notification ## Build, import into k3d, and restart notification-service
	@echo "📦 Importing notification-service into cluster..."
	k3d image import $(REGISTRY)/notification-service:latest -c $(CLUSTER_NAME)
	kubectl rollout restart deployment/notification-service -n $(SERVICES_NS)
	kubectl rollout status deployment/notification-service -n $(SERVICES_NS) --timeout=120s

dev-all: build-all ## Build and redeploy all services
	@echo "📦 Importing all images into cluster..."
	k3d image import \
		$(REGISTRY)/order-service:latest \
		$(REGISTRY)/inventory-service:latest \
		$(REGISTRY)/payment-service:latest \
		$(REGISTRY)/notification-service:latest \
		-c $(CLUSTER_NAME)
	kubectl rollout restart deployment/order-service deployment/inventory-service \
		deployment/payment-service deployment/notification-service -n $(SERVICES_NS)
	kubectl rollout status deployment/order-service -n $(SERVICES_NS) --timeout=120s
	kubectl rollout status deployment/inventory-service -n $(SERVICES_NS) --timeout=120s
	kubectl rollout status deployment/payment-service -n $(SERVICES_NS) --timeout=120s
	kubectl rollout status deployment/notification-service -n $(SERVICES_NS) --timeout=120s

# ─── Restart targets (no rebuild) ────────────────────────────────────────────

restart-order: ## Restart order-service pod without rebuilding
	kubectl rollout restart deployment/order-service -n $(SERVICES_NS)
	kubectl rollout status deployment/order-service -n $(SERVICES_NS) --timeout=120s

restart-inventory: ## Restart inventory-service pod without rebuilding
	kubectl rollout restart deployment/inventory-service -n $(SERVICES_NS)
	kubectl rollout status deployment/inventory-service -n $(SERVICES_NS) --timeout=120s

restart-payment: ## Restart payment-service pod without rebuilding
	kubectl rollout restart deployment/payment-service -n $(SERVICES_NS)
	kubectl rollout status deployment/payment-service -n $(SERVICES_NS) --timeout=120s

restart-notification: ## Restart notification-service pod without rebuilding
	kubectl rollout restart deployment/notification-service -n $(SERVICES_NS)
	kubectl rollout status deployment/notification-service -n $(SERVICES_NS) --timeout=120s

# ─── Log tailing ─────────────────────────────────────────────────────────────

logs-order: ## Tail order-service logs
	kubectl logs -n $(SERVICES_NS) deployment/order-service -f

logs-inventory: ## Tail inventory-service logs
	kubectl logs -n $(SERVICES_NS) deployment/inventory-service -f

logs-payment: ## Tail payment-service logs
	kubectl logs -n $(SERVICES_NS) deployment/payment-service -f

logs-notification: ## Tail notification-service logs
	kubectl logs -n $(SERVICES_NS) deployment/notification-service -f

# ─── Port-forwards ────────────────────────────────────────────────────────────

pf-grafana: ## Port-forward Grafana → localhost:3000
	kubectl port-forward svc/prometheus-grafana -n observability 3000:80

pf-prometheus: ## Port-forward Prometheus → localhost:9090
	kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n observability 9090:9090

pf-jaeger: ## Port-forward Jaeger UI → localhost:16686
	kubectl port-forward svc/jaeger-query -n observability 16686:16686

pf-redpanda: ## Port-forward Redpanda Console → localhost:8083
	kubectl port-forward svc/redpanda-console -n infra 8083:8080

pf-order: ## Port-forward order-service → localhost:8081
	kubectl port-forward svc/order-service -n $(SERVICES_NS) 8081:8080

pf-obs: ## Port-forward all observability tools in background
	@echo "📡 Starting observability port-forwards in background..."
	kubectl port-forward svc/prometheus-grafana -n observability 3000:80 &
	kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n observability 9090:9090 &
	kubectl port-forward svc/jaeger-query -n observability 16686:16686 &
	kubectl port-forward svc/redpanda-console -n infra 8083:8080 &
	@echo "✅ Grafana: http://localhost:3000  Prometheus: http://localhost:9090  Jaeger: http://localhost:16686  Redpanda: http://localhost:8083"

pf-all: pf-obs ## Port-forward observability tools + order-service
	kubectl port-forward svc/order-service -n $(SERVICES_NS) 8081:8080 &
	@echo "   Order API: http://localhost:8081"
