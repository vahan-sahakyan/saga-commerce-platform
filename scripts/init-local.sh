#!/bin/bash

# Initialize databases and Kafka topics for local development (production-style)
# Assumes PostgreSQL, Redis, and Redpanda are running via docker-compose

set -e

echo "🔧 Initializing Local Data Infrastructure..."
echo ""

# colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # no color

POSTGRES_HOST="localhost"
POSTGRES_PORT="5432"
POSTGRES_USER="saga"
POSTGRES_PASSWORD="saga-password"

# ─── Database Initialization ───────────────────────────────────────────────


echo "Force dropping and recreating service databases..."

echo ""
echo -e "${BLUE}📦 Creating PostgreSQL Databases...${NC}"

# parse args
FORCE_DROP=false
for arg in "$@"; do
  case $arg in
    --force-drop)
      FORCE_DROP=true
      ;;
  esac
done

# wait for postgresql to be ready
echo "Waiting for PostgreSQL to be ready..."
attempt=0
until PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d postgres -c "SELECT 1" &>/dev/null; do
  attempt=$((attempt + 1))
  if [ $attempt -gt 30 ]; then
    echo -e "${RED}✗ PostgreSQL is not available after 30 attempts${NC}"
    exit 1
  fi
  echo "PostgreSQL is unavailable - sleeping (attempt $attempt/30)"
  sleep 1
done
echo -e "${GREEN}✓ PostgreSQL is ready${NC}"

if [ "$FORCE_DROP" = true ]; then
  echo "Force dropping and recreating service databases..."
  for DB in order_db inventory_db payment_db; do
    echo "  - $DB: terminating connections..."
    PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB' AND pid <> pg_backend_pid();"
    echo "  - $DB: dropping..."
    PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d postgres -c "DROP DATABASE IF EXISTS $DB;"
    echo "  - $DB: creating..."
    PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_HOST -U $POSTGRES_USER -d postgres -c "CREATE DATABASE $DB;" 2>&1 || echo "  ℹ️  $DB may already exist"
    echo -e "${GREEN}✓ $DB${NC}"
  done
  echo ""
else
  echo "Skipping force drop. Databases will be left as-is."
fi


# ─── Schema Migrations (Production Style) ───────────────────────────────

echo -e "${BLUE}📜 Running schema migrations...${NC}"

# Inventory Service
echo "Migrating inventory_db..."
migrate -path ./services/inventory-service/migrations -database "postgres://saga:saga-password@localhost:5432/inventory_db?sslmode=disable" up
echo -e "${GREEN}✓ inventory_db migrated${NC}"

echo "Migrating payment_db..."
migrate -path ./services/payment-service/migrations -database "postgres://saga:saga-password@localhost:5432/payment_db?sslmode=disable" up
echo -e "${GREEN}✓ payment_db migrated${NC}"

# (Add similar blocks for order-service and payment-service if/when migrations exist)

# ─── Kafka Topic Initialization ────────────────────────────────────────────

echo -e "${BLUE}🚀 Creating Kafka Topics...${NC}"

# wait for redpanda to be ready
echo "Waiting for Redpanda to be ready..."
attempt=0
until docker exec saga-redpanda rpk cluster info -X brokers=localhost:9092 &>/dev/null; do
  attempt=$((attempt + 1))
  if [ $attempt -gt 30 ]; then
    echo -e "${RED}✗ Redpanda is not available after 30 attempts${NC}"
    exit 1
  fi
  echo "Redpanda is unavailable - sleeping (attempt $attempt/30)"
  sleep 1
done
echo -e "${GREEN}✓ Redpanda is ready${NC}"

# create topics
echo "Creating Kafka topics..."
docker exec saga-redpanda rpk topic create order-events -p 1 -r 1 2>&1 | grep -i "ok\|already" || true
echo -e "${GREEN}✓ order-events${NC}"

docker exec saga-redpanda rpk topic create inventory-events -p 1 -r 1 2>&1 | grep -i "ok\|already" || true
echo -e "${GREEN}✓ inventory-events${NC}"

docker exec saga-redpanda rpk topic create payment-events -p 1 -r 1 2>&1 | grep -i "ok\|already" || true
echo -e "${GREEN}✓ payment-events${NC}"

docker exec saga-redpanda rpk topic create shipping-events -p 1 -r 1 2>&1 | grep -i "ok\|already" || true
echo -e "${GREEN}✓ shipping-events${NC}"

docker exec saga-redpanda rpk topic create notification-events -p 1 -r 1 2>&1 | grep -i "ok\|already" || true
echo -e "${GREEN}✓ notification-events${NC}"

echo ""
echo -e "${GREEN}✅ Data infrastructure initialized successfully!${NC}"
echo ""
echo "Services are configured to use:"
echo "  PostgreSQL:       localhost:5432 (user: saga)"
echo "  Redis:            localhost:6379"
echo "  Kafka/Redpanda:   localhost:9092"
echo ""
echo "You can now build and run services locally"
