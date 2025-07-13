# PaC-BoF: Patient-Centric Blockchain Framework for Healthcare Data Management

## 1. Project Overview

This project implements **PaC-BoF (Patient-Centric Blockchain Framework)**, a system designed to address critical challenges in healthcare data management within smart city ecosystems. It focuses on enhancing:

*   **Data Security & Privacy:** Utilizing blockchain's inherent security features and encryption.
*   **Interoperability:** Enabling seamless data exchange between different healthcare providers and smart city services.
*   **Patient Data Autonomy:** Empowering patients with control over their medical records.
*   **Scalability:** Handling large volumes of data, including from IoMT devices.
*   **Regulatory Compliance:** Adhering to standards like GDPR and HIPAA.

The framework is based on the research presented in `paper.txt`, detailing a patient-centric approach to managing sensitive health information.

## 2. Architecture

PaC-BoF employs a five-layer architecture:

1.  **Data Ownership and Access Control Layer:** Manages digital identities, patient consent, and access policies via smart contracts.
2.  **Blockchain-Based Data Management Layer:** The core Hyperledger Fabric network managing ledger, transaction integrity, and pointers to off-chain data.
3.  **Smart City Ecosystem Integration Layer:** Provides APIs for integrating with external systems, IoT devices, and adhering to standards like HL7 FHIR.
4.  **Analytics and Reporting Layer:** Enables data analytics and machine learning on aggregated, anonymized data.
5.  **Regulatory Compliance and Governance Layer:** Ensures adherence to legal and ethical standards (GDPR, HIPAA), including data retention and auditing.

## 3. Technology Stack

*   **Blockchain Platform:** Hyperledger Fabric (v2.x+)
*   **Chaincode Language:** Go (using Fabric Contract API)
*   **Development Tools:** Docker, Docker Compose, Go, Node.js (for SDK/testing), `peer` CLI, `configtxgen`, `cryptogen`, `git`, `jq`.
*   **Data Storage:** Off-chain storage (e.g., IPFS, secure cloud object storage) with on-chain hashes/pointers.
*   **APIs:** RESTful APIs for integration.
*   **Standards:** HL7 FHIR (for data models).

## 4. Development Environment Setup

### 4.1. Prerequisites

*   **Operating System:** Linux (recommended), macOS, or Windows (with WSL2).
*   **Required Software:**
    *   **Docker:** Install Docker Engine and Docker Compose.
    *   **Go:** Install Go programming language (version 1.19 or later recommended).
    *   **Node.js:** Install Node.js (LTS version recommended, e.g., v18 or v20).
    *   **Git:** For version control.
    *   **Text Editor/IDE:** VS Code with Go and Docker extensions, or your preferred editor.

### 4.2. Hyperledger Fabric Installation

Follow the official Hyperledger Fabric documentation to install the necessary binaries and Docker images:
[https://hyperledger-fabric.readthedocs.io/en/latest/install.html](https://hyperledger-fabric.readthedocs.io/en/latest/install.html)

*   **Install Fabric Binaries & Samples:** Use the `install-fabric.sh` script. We've used specific versions for reproducibility:
    ```bash
    # Navigate to a directory for tools, e.g., your home directory
    cd ~ 
    
    # Download the installation script
    curl -sSL https://raw.githubusercontent.com/hyperledger/fabric/main/scripts/install-fabric.sh -o install-fabric.sh
    chmod +x install-fabric.sh
    
    # Run the installation script (adjust versions if needed)
    ./install-fabric.sh --fabric-version 2.5.13 --fabric-ca-version 1.5.15
    ```

### 4.3. Shell Configuration (`~/.zshrc`)

Ensure your shell environment is clean and correctly configured. **Please follow these steps:**

1.  **Backup:** Save your current `.zshrc`: `cp ~/.zshrc ~/.zshrc.backup`
2.  **Replace Content:** Replace the entire content of your `~/.zshrc` with the version below.
3.  **Reload Shell:** Run `source ~/.zshrc` or open a new terminal window.

```zsh
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"
export PATH="$HOME/.local/bin:$PATH"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# HIST_STAMPS="mm/dd/yyyy"

# Which plugins would you like to load?
plugins=(git)

source $ZSH/oh-my-zsh.sh

# User configuration

# Personal aliases, overriding those provided by Oh My Zsh libs, plugins, and themes.
# For a full list of active aliases, run `alias`.
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.ohmyzsh"

# NVM and Go paths
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
export PATH=$PATH:/usr/local/go/bin

# ========================================
# Hyperledger Fabric Paths
# ========================================
# Ensure FABRIC_SAMPLES_PATH points to your actual installation directory
export FABRIC_SAMPLES_PATH="/home/luka/fabric-samples"
export FABRIC_CFG_PATH="$FABRIC_SAMPLES_PATH/config"
export PATH="$FABRIC_SAMPLES_PATH/bin:$PATH"

# ========================================
# Project Specific Paths (PaC-BoF)
# ========================================
export PACBOF_ROOT="/home/luka/Documents/dev/pacbof-health-chain"

# Quick navigation aliases (defined correctly without export)
alias goto-pacbof="cd $PACBOF_ROOT"
alias goto-network="cd $PACBOF_ROOT/blockchain/network/pacbof-network"
alias goto-fabric="cd $FABRIC_SAMPLES_PATH"

# Fabric environment verification function (defined correctly, then exported)
verify_fabric_env() {
    echo "🔧 Fabric Environment Status:"
    echo "   Fabric Samples Path: $FABRIC_SAMPLES_PATH"
    echo "   Fabric Config Path: $FABRIC_CFG_PATH"
    echo "   Fabric Binaries in PATH: $(which peer 2>/dev/null || echo 'Not found')"
    echo "   Peer Version: $(peer version 2>/dev/null | grep Version | cut -d' ' -f2 || echo 'Not accessible')"
    echo "   Fabric CA Client Version: $(fabric-ca-client version 2>/dev/null | grep Version | cut -d' ' -f2 || echo 'Not accessible')"
}

# Export functions for availability in subshells
export -f verify_fabric_env
