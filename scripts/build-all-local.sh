#!/bin/bash

# Convenience script to build and start all services locally
# This script requires all services to be run in separate terminals

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🚀 Building all services..."
echo ""

# colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # no color

# ─── Build Services ───────────────────────────────────────────────────────

echo -e "${BLUE}Building Order Service (Java)...${NC}"
cd "$REPO_ROOT/services/order-service"
mvn clean package -q
echo -e "${GREEN}✓ Order Service built${NC}"
echo ""

echo -e "${BLUE}Building Inventory Service (Go)...${NC}"
cd "$REPO_ROOT/services/inventory-service"
go build -o bin/inventory-service cmd/server/main.go
echo -e "${GREEN}✓ Inventory Service built${NC}"
echo ""

echo -e "${BLUE}Building Payment Service (Python)...${NC}"
cd "$REPO_ROOT/services/payment-service"
pip install -q -r requirements.txt
echo -e "${GREEN}✓ Payment Service dependencies installed${NC}"
echo ""

echo -e "${BLUE}Building Notification Service (TypeScript)...${NC}"
cd "$REPO_ROOT/services/notification-service"
npm install -q
npm run build
echo -e "${GREEN}✓ Notification Service built${NC}"
echo ""

# ─── Instructions ─────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}✅ All services built successfully!${NC}"
echo ""
echo -e "${YELLOW}Next: Open 4 terminals and run each service:${NC}"
echo ""
echo "Terminal 1 (Order Service - Java):"
echo "  cd $REPO_ROOT/services/order-service"
echo "  mvn spring-boot:run"
echo ""
echo "Terminal 2 (Inventory Service - Go):"
echo "  cd $REPO_ROOT/services/inventory-service"
echo "  go run cmd/server/main.go"
echo ""
echo "Terminal 3 (Payment Service - Python):"
echo "  cd $REPO_ROOT/services/payment-service"
echo "  python app/main.py"
echo ""
echo "Terminal 4 (Notification Service - TypeScript):"
echo "  cd $REPO_ROOT/services/notification-service"
echo "  npm run dev"
echo ""
echo -e "${YELLOW}All services will be ready in ~10-15 seconds${NC}"
