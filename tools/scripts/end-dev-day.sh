#!/bin/bash

# end-dev-day.sh
# This script gracefully shuts down the PaC-BoF Hyperledger Fabric network.

# Exit immediately if a command exits with a non-zero status.
set -e

echo "😴 Ending PaC-BoF Development Day..."
echo "=================================="

# Navigate to the project root directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT=$(dirname $(dirname "$SCRIPT_DIR"))
cd "$PROJECT_ROOT"

echo "📍 Current working directory: $(pwd)"

# Source the .zshrc to ensure aliases and functions are available
echo "🔄 Reloading shell environment..."
source ~/.zshrc

echo "Stopping Docker Compose network..."
# Navigate to the network directory to run network.sh down
if [ -d "./blockchain/network/pacbof-network" ]; then
    cd "./blockchain/network/pacbof-network"
    # Call the network.sh script to bring down the network
    ./network.sh down
    echo "✅ Hyperledger Fabric network is stopped."
else
    echo "⚠️ Network configuration directory not found. Cannot stop network."
fi

# Clean up any other temporary artifacts if necessary (add more commands here if needed)
echo "🧹 Cleaning up temporary files (if any)..."
# Example: docker system prune -f (be careful with this in shared environments)
# Example: docker volume prune -f (be careful with this)

echo "😴 PaC-BoF development session ended."
echo "Have a great break!"
