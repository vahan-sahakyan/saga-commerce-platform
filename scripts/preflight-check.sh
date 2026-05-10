#!/bin/bash

# Pre-flight check script for Saga Commerce Platform

set -e

echo "🔍 Saga Commerce Platform - Pre-flight Check"
echo ""

# colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # no color

# track issues
ISSUES=0

# function to check command
check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 is installed ($(command -v $1))"
        if [ ! -z "$2" ]; then
            VERSION=$($1 $2 2>&1 | head -1)
            echo "  Version: $VERSION"
        fi
        return 0
    else
        echo -e "${RED}✗${NC} $1 is NOT installed"
        if [ ! -z "$3" ]; then
            echo "  Install: $3"
        fi
        ISSUES=$((ISSUES + 1))
        return 1
    fi
}

echo "📦 Checking Core Dependencies..."
echo ""

# Docker
check_command "docker" "--version" "brew install docker"

# k3d
check_command "k3d" "version" "brew install k3d"

# kubectl
check_command "kubectl" "version --client --short" "brew install kubectl"

# helm
check_command "helm" "version --short" "brew install helm"

# terraform
check_command "terraform" "version" "brew install terraform"

# jq
check_command "jq" "--version" "brew install jq"

echo ""
echo "🛠️  Checking Build Tools (Optional - for building services)..."
echo ""

# Java/Maven
if check_command "java" "--version" "brew install openjdk@17"; then
    if check_command "mvn" "--version" "brew install maven"; then
        echo -e "${GREEN}  → Can build order-service${NC}"
    else
        echo -e "${YELLOW}  → mvnw wrapper will be used for order-service${NC}"
    fi
else
    echo -e "${YELLOW}  → Cannot build order-service (Java required)${NC}"
fi

# Go
if check_command "go" "version" "brew install go"; then
    echo -e "${GREEN}  → Can build inventory-service${NC}"
else
    echo -e "${YELLOW}  → Cannot build inventory-service (Go required)${NC}"
fi

# Python
if check_command "python3" "--version" "brew install python@3.11"; then
    echo -e "${GREEN}  → Can build payment-service${NC}"
else
    echo -e "${YELLOW}  → Cannot build payment-service (Python required)${NC}"
fi

# Node.js
if check_command "node" "--version" "brew install node"; then
    if check_command "npm" "--version" "brew install node"; then
        echo -e "${GREEN}  → Can build notification-service${NC}"
    fi
else
    echo -e "${YELLOW}  → Cannot build notification-service (Node.js required)${NC}"
fi

echo ""
echo "🐳 Checking Docker..."

if docker info &> /dev/null; then
    echo -e "${GREEN}✓${NC} Docker daemon is running"
    docker version | grep "Version:" | head -2
else
    echo -e "${RED}✗${NC} Docker daemon is NOT running"
    echo "  Please start Docker Desktop"
    ISSUES=$((ISSUES + 1))
fi

echo ""
echo "📊 Summary"
echo "=========="

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ All core dependencies are installed!${NC}"
    echo ""
    echo "🚀 You're ready to run:"
    echo "   make bootstrap"
    echo ""
else
    echo -e "${RED}✗ Found $ISSUES issue(s)${NC}"
    echo ""
    echo "Please install the missing dependencies and try again."
    echo ""
    echo "Quick install (macOS):"
    echo "  brew install docker k3d kubectl helm terraform jq"
    echo "  brew install openjdk@17 go python@3.11 node"
    echo ""
    exit 1
fi

echo "Optional: Check GETTING_STARTED.md for detailed instructions"
