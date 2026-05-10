#!/bin/bash

# Step-by-step runner for Saga Commerce Platform
# This script will guide you through running the platform

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Saga Commerce Platform - Interactive Setup            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Function to wait for user
wait_for_user() {
    echo ""
    read -p "Press ENTER to continue..."
    echo ""
}

# Function to run command with explanation
run_step() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "$2"
    echo ""
    if [ "$3" != "skip-wait" ]; then
        wait_for_user
    fi
    echo "Running: $4"
    echo ""
    eval "$4"
    echo ""
}

# Step 1: Check dependencies
run_step "Step 1: Check Dependencies" \
    "First, let's verify all required tools are installed." \
    "continue" \
    "./scripts/preflight-check.sh || echo 'Some dependencies are missing. Run: ./scripts/install-deps.sh'"

# Step 2: Bootstrap infrastructure
run_step "Step 2: Bootstrap Infrastructure (5-10 minutes)" \
    "This will:
  • Create a k3d Kubernetes cluster
  • Install ArgoCD (GitOps)
  • Deploy Redpanda (Kafka)
  • Deploy PostgreSQL databases
  • Deploy Redis cache
  • Deploy Prometheus, Grafana, Jaeger

This may take 5-10 minutes on first run." \
    "ask" \
    "make bootstrap"

# Step 3: Check cluster status
run_step "Step 3: Verify Cluster Status" \
    "Let's verify everything is running correctly." \
    "skip-wait" \
    "kubectl get pods -A | grep -v Completed"

wait_for_user

# Step 4: Build services
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Step 4: Build Services (5-10 minutes)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "This will build Docker images for all 4 services:"
echo "  • order-service (Java/Spring Boot)"
echo "  • inventory-service (Go)"
echo "  • payment-service (Python/FastAPI)"
echo "  • notification-service (TypeScript/Fastify)"
echo ""
echo "NOTE: First build may take 5-10 minutes to download dependencies."
echo ""
read -p "Do you want to build all services? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Building services..."
    ./scripts/build-all.sh
else
    echo -e "${YELLOW}⚠️  Skipping build. You can build later with: ./scripts/build-all.sh${NC}"
fi

wait_for_user

# Step 5: Deploy services
run_step "Step 5: Deploy Services via ArgoCD" \
    "This deploys all services to Kubernetes using GitOps." \
    "ask" \
    "make deploy"

echo "Waiting for services to be ready..."
sleep 10

# Step 6: Seed test data
run_step "Step 6: Seed Test Data" \
    "Adding test products to inventory database." \
    "ask" \
    "./scripts/seed-data.sh"

# Step 7: Test the saga
run_step "Step 7: Test the Saga Flow" \
    "This will create a test order and watch it flow through all services.

You'll need to port-forward the order-service in another terminal:
  kubectl port-forward svc/order-service -n services 8080:8080

Then run the test." \
    "ask" \
    "echo 'Run: ./scripts/test-saga.sh after port-forwarding'"

# Success!
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           🎉 Setup Complete! 🎉                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "📊 Access your platform:"
echo ""
echo "  Services:"
echo "    Order API:    kubectl port-forward svc/order-service -n services 8080:8080"
echo ""
echo "  Observability:"
echo "    ArgoCD:       kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "    Grafana:      kubectl port-forward svc/prometheus-grafana -n observability 3000:80"
echo "    Jaeger:       kubectl port-forward svc/jaeger-query -n observability 16686:16686"
echo "    Prometheus:   kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n observability 9090:9090"
echo ""
echo "  Get ArgoCD password:"
echo "    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "📖 Next steps:"
echo "  • Read GETTING_STARTED.md for detailed usage"
echo "  • Check STATUS.md for implementation details"
echo "  • View logs: kubectl logs -l app=order-service -n services"
echo ""
echo "🧹 To clean up:"
echo "  make destroy"
echo ""
