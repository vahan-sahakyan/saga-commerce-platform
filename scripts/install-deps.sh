#!/bin/bash

# Quick Install Script for Saga Commerce Platform

echo "🚀 Quick Install - Saga Commerce Platform"
echo ""
echo "This script will install all required dependencies on macOS using Homebrew."
echo ""

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew is not installed."
    echo ""
    echo "Install Homebrew first:"
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    echo ""
    exit 1
fi

echo "📦 Installing core dependencies..."
echo ""

# Core dependencies (required)
brew install k3d kubectl helm terraform jq

echo ""
echo "🛠️  Installing build tools (optional but recommended)..."
echo ""

# Build tools (optional)
brew install openjdk@17 go python@3.11 node maven

echo ""
echo "✅ Installation complete!"
echo ""
echo "🚀 Next steps:"
echo "   1. Start Docker Desktop"
echo "   2. Run: make bootstrap"
echo "   3. Follow the GETTING_STARTED.md guide"
