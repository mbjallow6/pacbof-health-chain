#!/bin/bash

# start-dev-day.sh
# This script sets up the development environment for PaC-BoF.

# Exit immediately if a command exits with a non-zero status.
set -e

echo "🚀 Starting PaC-BoF Development Day..."
echo "=================================="

# Navigate to the project root directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT=$(dirname $(dirname "$SCRIPT_DIR"))
cd "$PROJECT_ROOT"

echo "📍 Current working directory: $(pwd)"

# Source the .zshrc to ensure all environment variables are loaded
# This is crucial for Fabric paths, Go, Node.js, and custom aliases/functions.
echo "🔄 Reloading shell environment..."
source ~/.zshrc

# Verify Fabric environment (using the function defined in .zshrc)
echo "🔍 Verifying Hyperledger Fabric environment..."
verify_fabric_env

# Check if Fabric binaries are found
if ! command -v peer &> /dev/null || ! command -v configtxgen &> /dev/null || ! command -v cryptogen &> /dev/null; then
    echo "❌ Hyperledger Fabric binaries (peer, configtxgen, cryptogen) not found or not in PATH."
    echo "Please ensure Fabric is installed and your ~/.zshrc is correctly sourced."
    exit 1
fi

echo "✅ Hyperledger Fabric environment is ready."

echo "Starting Docker Compose network (if not already running)..."
# Navigate to the network directory to run docker-compose
if [ -d "./blockchain/network/pacbof-network" ]; then
    cd "./blockchain/network/pacbof-network"
    # Call the network.sh script to bring up the network
    # We will only call 'up' here; channel creation and chaincode deployment will be separate steps
    # or part of a more specific setup script called from start-dev-day.sh
    ./network.sh up || true # Use true to allow script to continue if network is already up
    echo "Network check completed. You can now use 'goto-network' and other aliases."
else
    echo "⚠️ Network configuration directory not found. Please ensure it's set up."
fi

echo "✅ PaC-BoF development environment is set up."
echo "You can now navigate using 'goto-pacbof', 'goto-network', 'goto-fabric' and start working."
