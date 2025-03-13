#!/bin/bash

# Auto-Handling Bash Script for DA Node and DA Signer Setup
# Ensure you run this script as a user with sudo privileges

set -e  # Exit on error

# Variables
REPO_URL="https://github.com/0glabs/0g-da-node.git"
DATA_PATH="/data"
PARAMS_PATH="/params"
CONFIG_FILE="config.toml"
DOCKER_IMAGE_NAME="0g-da-node"
DOCKER_CONTAINER_NAME="0g-da-node"
GRPC_PORT="34000"
ETH_RPC_ENDPOINT="https://evmrpc-testnet.0g.ai"
DA_ENTRANCE_ADDRESS="0x857C0A28A8634614BB2C96039Cf4a20AFF709Aa9"
START_BLOCK_NUMBER="940000"

# Function to install dependencies
install_dependencies() {
    echo "Installing required dependencies..."
    sudo apt-get update
    sudo apt-get install -y \
        git \
        curl \
        build-essential \
        docker.io \
        docker-compose \
        cargo
    echo "Dependencies installed."
}

# Function to install Rust
install_rust() {
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
    echo "Rust installed."
}

# Function to clone the repository
clone_repo() {
    echo "Cloning the DA Node repository..."
    git clone $REPO_URL
    cd 0g-da-node
    echo "Repository cloned."
}

# Function to generate BLS private key
generate_bls_key() {
    echo "Generating BLS private key..."
    cargo run --bin key-gen > bls_key.txt
    BLS_PRIVATE_KEY=$(grep "Private Key:" bls_key.txt | awk '{print $3}')
    echo "=============================================="
    echo "Generated BLS Private Key: $BLS_PRIVATE_KEY"
    echo "=============================================="
    echo "Please make a backup of this key. It will not be shown again."
    echo "=============================================="
}

# Function to prompt for miner_eth_private_key
get_miner_eth_private_key() {
    read -p "Enter your Miner ETH Private Key: " MINER_ETH_PRIVATE_KEY
    if [ -z "$MINER_ETH_PRIVATE_KEY" ]; then
        echo "Error: Miner ETH Private Key cannot be empty."
        exit 1
    fi
}

# Function to create config.toml
create_config() {
    echo "Creating $CONFIG_FILE..."
    cat <<EOL > $CONFIG_FILE
log_level = "info"

data_path = "$DATA_PATH"

# Path to downloaded params folder
encoder_params_dir = "$PARAMS_PATH"

# gRPC server listen address
grpc_listen_address = "0.0.0.0:$GRPC_PORT"

# Chain ETH RPC endpoint
eth_rpc_endpoint = "$ETH_RPC_ENDPOINT"

# Public gRPC service socket address to register in DA contract
socket_address = "$(curl -s ifconfig.me):$GRPC_PORT"

# Data availability contract to interact with
da_entrance_address = "$DA_ENTRANCE_ADDRESS"

# Deployed block number of DA entrance contract
start_block_number = $START_BLOCK_NUMBER

# Signer BLS private key
signer_bls_private_key = "$BLS_PRIVATE_KEY"

# Signer ETH account private key (same as miner_eth_private_key)
signer_eth_private_key = "$MINER_ETH_PRIVATE_KEY"

# Miner ETH account private key
miner_eth_private_key = "$MINER_ETH_PRIVATE_KEY"

# Whether to enable data availability sampling
enable_das = "true"
EOL
    echo "$CONFIG_FILE created."
}

# Function to build and run Docker container
run_docker() {
    echo "Building Docker image..."
    docker build -t $DOCKER_IMAGE_NAME .

    echo "Running Docker container..."
    docker run -d \
        --name $DOCKER_CONTAINER_NAME \
        -v $DATA_PATH:/data \
        -v $PARAMS_PATH:/params \
        -p $GRPC_PORT:$GRPC_PORT \
        $DOCKER_IMAGE_NAME

    echo "Docker container is running."
}

# Function to verify the node is running
verify_node() {
    echo "Verifying the node is running..."
    docker logs $DOCKER_CONTAINER_NAME --tail 50
    echo "Node verification complete. Check logs above for any errors."
}

# Main function
main() {
    install_dependencies
    install_rust
    clone_repo
    generate_bls_key
    get_miner_eth_private_key
    create_config
    run_docker
    verify_node
    echo "DA Node setup completed successfully!"
}

# Execute the script
main
