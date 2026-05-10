#!/bin/bash

set -e

echo "🚀 Starting saga-commerce-platform bootstrap..."

# check prerequisites
command -v docker >/dev/null 2>&1 || { echo "❌ docker is required but not installed"; exit 1; }
command -v k3d >/dev/null 2>&1 || { echo "❌ k3d is required but not installed"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "❌ helm is required but not installed"; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "❌ terraform is required but not installed"; exit 1; }

echo "✅ All prerequisites satisfied"
echo ""
echo "📦 Creating k3d cluster..."
k3d cluster create saga-platform --config infra/bootstrap/k3d-config.yaml || echo "Cluster already exists"

echo ""
echo "⏳ Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo ""
echo "🏗️  Installing infrastructure with Terraform..."
cd infra/terraform
terraform init
terraform apply -auto-approve
cd ../..

echo ""
echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

echo ""
echo "✅ Bootstrap complete!"
echo ""
echo "📝 Next steps:"
echo "  1. Get ArgoCD admin password:"
echo "     kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "  2. Access ArgoCD UI:"
echo "     kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  3. Deploy services:"
echo "     make deploy"
