#!/bin/bash

# Define colors for output
GREEN="\033[0;32m"
RESET="\033[0m"

echo -e "${GREEN}🚀 Starting 0G DA Node Setup...${RESET}"

# Update system and install required dependencies
echo -e "${GREEN}🔄 Updating system packages...${RESET}"
sudo apt update -y && sudo apt upgrade -y

echo -e "${GREEN}⚙️ Installing dependencies...${RESET}"
sudo apt install -y git curl wget docker.io docker-compose build-essential

# Install Rust (if not installed)
if ! command -v cargo &> /dev/null; then
    echo -e "${GREEN}📦 Installing Rust...${RESET}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
else
    echo -e "${GREEN}✅ Rust is already installed.${RESET}"
fi

# Clone 0G DA Node repository
echo -e "${GREEN}🔽 Cloning 0G DA Node repository...${RESET}"
git clone https://github.com/0glabs/0g-da-node.git ~/0g-da-node
cd ~/0g-da-node

# Generate BLS private key (if needed)
if [ ! -f bls_key.txt ]; then
    echo -e "${GREEN}🔑 Generating BLS Private Key...${RESET}"
    cargo run --bin key-gen > bls_key.txt
    BLS_PRIVATE_KEY=$(cat bls_key.txt | grep -oP '(?<=Private key: ).*')
    echo -e "${GREEN}✅ BLS Private Key generated and saved.${RESET}"
else
    echo -e "${GREEN}🔑 Existing BLS Private Key found.${RESET}"
    BLS_PRIVATE_KEY=$(cat bls_key.txt | grep -oP '(?<=Private key: ).*')
fi

# Extract the BLS key
BLS_KEY=$(cat ~/0g-da-node/bls_key.txt | tr -d '\n')

# Insert BLS Key into config.toml
sed -i "s|signer_bls_private_key = \"\"|signer_bls_private_key = \"$BLS_KEY\"|g" ~/0g-da-node/config.toml
echo "✅ BLS Key successfully added to config.toml!"

# Prompt user for Ethereum private keys
read -p "🔑 Enter your Ethereum Signer Private Key: " SIGNER_ETH_KEY
read -p "🔑 Enter your Ethereum Miner Private Key: " MINER_ETH_KEY

# Create config.toml file
echo -e "${GREEN}📝 Creating config.toml file...${RESET}"
cat <<EOF > config.toml
log_level = "info"
data_path = "/data"

# Path to downloaded params folder
encoder_params_dir = "/params"

# gRPC server listen address
grpc_listen_address = "0.0.0.0:34000"

# Chain eth rpc endpoint
eth_rpc_endpoint = "https://evmrpc-testnet.0g.ai"

# Public gRPC service socket address to register in DA contract
socket_address = "<your_public_ip>:34000"

# Data Availability contract info
da_entrance_address = "0x857C0A28A8634614BB2C96039Cf4a20AFF709Aa9"
start_block_number = 940000

# Private keys
signer_bls_private_key = "$BLS_PRIVATE_KEY"
signer_eth_private_key = "$SIGNER_ETH_KEY"
miner_eth_private_key = "$MINER_ETH_KEY"

# Enable data availability sampling
enable_das = "true"
EOF
echo -e "${GREEN}✅ Configuration file created.${RESET}"

# Build and start the Docker container
echo -e "${GREEN}🐳 Building and running the Docker container...${RESET}"
docker build -t 0g-da-node .
docker run -d --name 0g-da-node 0g-da-node

# Display success message
echo -e "${GREEN}🎉 0G DA Node setup complete!${RESET}"
echo -e "👉 Use 'docker logs -f 0g-da-node' to monitor logs."
