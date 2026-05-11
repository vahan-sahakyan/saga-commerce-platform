#!/bin/bash

# Initialize databases and Kafka topics for the saga platform
# This ensures all required infrastructure is ready before deploying services

set -e

echo "🔧 Initializing Saga Platform Data Infrastructure..."
echo ""

# colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # no color

POSTGRES_HOST="postgresql.infra.svc.cluster.local"
POSTGRES_PORT="5432"
POSTGRES_USER="saga"
POSTGRES_PASSWORD="saga-password"
POSTGRES_DB="saga"

KAFKA_BROKER="redpanda.infra.svc.cluster.local:9093"

# ─── Database Initialization ───────────────────────────────────────────────

echo -e "${BLUE}📦 Creating PostgreSQL Databases...${NC}"

# wait for postgresql to be ready
echo "Waiting for PostgreSQL to be ready..."
until kubectl exec postgresql-0 -n infra -- pg_isready -h localhost -U saga &>/dev/null; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done
echo -e "${GREEN}✓ PostgreSQL is ready${NC}"

# create databases
echo "Creating service databases..."
kubectl exec postgresql-0 -n infra -- bash -c "PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -d $POSTGRES_DB -c 'CREATE DATABASE order_db;'" 2>&1 || echo "  ℹ️  order_db may already exist"
echo -e "${GREEN}✓ order_db${NC}"

kubectl exec postgresql-0 -n infra -- bash -c "PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -d $POSTGRES_DB -c 'CREATE DATABASE inventory_db;'" 2>&1 || echo "  ℹ️  inventory_db may already exist"
echo -e "${GREEN}✓ inventory_db${NC}"

kubectl exec postgresql-0 -n infra -- bash -c "PGPASSWORD=$POSTGRES_PASSWORD psql -U $POSTGRES_USER -d $POSTGRES_DB -c 'CREATE DATABASE payment_db;'" 2>&1 || echo "  ℹ️  payment_db may already exist"
echo -e "${GREEN}✓ payment_db${NC}"

echo ""

# ─── Kafka Topic Initialization ────────────────────────────────────────────

echo -e "${BLUE}🚀 Creating Kafka Topics...${NC}"

# wait for redpanda to be ready
echo "Waiting for Redpanda to be ready..."
until kubectl exec redpanda-0 -n infra -- rpk cluster info -X brokers="$KAFKA_BROKER" &>/dev/null; do
  echo "Redpanda is unavailable - sleeping"
  sleep 2
done
echo -e "${GREEN}✓ Redpanda is ready${NC}"

# create topics
echo "Creating Kafka topics..."
kubectl exec redpanda-0 -n infra -- rpk topic create order-events -p 1 -r 1 2>&1 | grep -i "ok\|already" || true
echo -e "${GREEN}✓ order-events${NC}"

kubectl exec redpanda-0 -n infra -- rpk topic create inventory-events -p 1 -r 1 2>&1 | grep -i "ok\|already" || true
echo -e "${GREEN}✓ inventory-events${NC}"

kubectl exec redpanda-0 -n infra -- rpk topic create payment-events -p 1 -r 1 2>&1 | grep -i "ok\|already" || true
echo -e "${GREEN}✓ payment-events${NC}"

kubectl exec redpanda-0 -n infra -- rpk topic create notification-events -p 1 -r 1 2>&1 | grep -i "ok\|already" || true
echo -e "${GREEN}✓ notification-events${NC}"

echo ""
echo -e "${GREEN}✅ Data infrastructure initialized successfully!${NC}"
echo ""
echo "Now you can deploy services:"
echo "  make deploy"
