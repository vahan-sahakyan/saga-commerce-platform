#!/bin/bash

set -e

echo "🏗️  Building all services..."

# colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # no color

# function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# check prerequisites
echo "📋 Checking prerequisites..."

if ! command_exists docker; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker${NC}"

# build order-service
if command_exists mvn || [ -f services/order-service/mvnw ]; then
    echo -e "\n${BLUE}📦 Building order-service (Java/Spring Boot)...${NC}"
    cd services/order-service
    if [ -f ./mvnw ]; then
        ./mvnw clean package -DskipTests
    else
        mvn clean package -DskipTests
    fi
    docker build -t localhost:5001/order-service:latest .
    docker push localhost:5001/order-service:latest
    echo -e "${GREEN}✅ order-service built${NC}"
    cd ../..
else
    echo -e "${RED}⚠️  Maven not found, skipping order-service${NC}"
fi

# build inventory-service
if command_exists go; then
    echo -e "\n${BLUE}📦 Building inventory-service (Go)...${NC}"
    cd services/inventory-service
    go mod download
    docker build -t localhost:5001/inventory-service:latest .
    docker push localhost:5001/inventory-service:latest
    echo -e "${GREEN}✅ inventory-service built${NC}"
    cd ../..
else
    echo -e "${RED}⚠️  Go not found, skipping inventory-service${NC}"
fi

# build payment-service
if command_exists python3; then
    echo -e "\n${BLUE}📦 Building payment-service (Python/FastAPI)...${NC}"
    cd services/payment-service
    docker build -t localhost:5001/payment-service:latest .
    docker push localhost:5001/payment-service:latest
    echo -e "${GREEN}✅ payment-service built${NC}"
    cd ../..
else
    echo -e "${RED}⚠️  Python not found, skipping payment-service${NC}"
fi

# build notification-service
if command_exists npm; then
    echo -e "\n${BLUE}📦 Building notification-service (TypeScript/Fastify)...${NC}"
    cd services/notification-service
    docker build -t localhost:5001/notification-service:latest .
    docker push localhost:5001/notification-service:latest
    echo -e "${GREEN}✅ notification-service built${NC}"
    cd ../..
else
    echo -e "${RED}⚠️  npm not found, skipping notification-service${NC}"
fi

echo -e "\n${GREEN}🎉 All services built successfully!${NC}"
