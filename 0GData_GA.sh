#!/bin/bash

printf "\n"
cat <<EOF
🚀 0G DA Node Setup Script 🚀

░██████╗░░█████╗░  ░█████╗░██████╗░██╗░░░██╗██████╗░████████╗░█████╗░
██╔════╝░██╔══██╗  ██╔══██╗██╔══██╗╚██╗░██╔╝██╔══██╗╚══██╔══╝██╔══██╗
██║░░██╗░███████║  ██║░░╚═╝██████╔╝░╚████╔╝░██████╔╝░░░██║░░░██║░░██║
██║░░╚██╗██╔══██║  ██║░░██╗██╔══██╗░░╚██╔╝░░██╔═══╝░░░░██║░░░██║░░██║
╚██████╔╝██║░░██║  ╚█████╔╝██║░░██║░░░██║░░░██║░░░░░░░░██║░░░╚█████╔╝
░╚═════╝░╚═╝░░╚═╝  ░╚════╝░╚═╝░░╚═╝░░░╚═╝░░░╚═╝░░░░░░░░╚═╝░░░░╚════╝░

EOF

printf "\n\n"

##########################################################################################
#                                                                                        
#                🚀 THIS SCRIPT IS PROUDLY CREATED BY **GA CRYPTO**! 🚀                  
#                                                                                        
#   🌐 Join our revolution in decentralized networks and crypto innovation!               
#                                                                                        
# 📢 Stay updated:                                                                      
#     • Follow us on Telegram: https://t.me/GaCryptOfficial                             
#     • Follow us on X: https://x.com/GACryptoO                                         
##########################################################################################

# Define colors
GREEN="\033[0;32m"
RESET="\033[0m"

# Print welcome message
printf "${GREEN}"
printf "🚀 Setting up 0G DA Node...\n"
printf "${RESET}"

# Ensure script is running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run this script as root!"
    exit 1
fi

# Stop and remove existing container if running
echo "🛑 Stopping any existing 0G DA Node container..."
docker stop 0g-da-node 2>/dev/null
docker rm 0g-da-node 2>/dev/null

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

# Clone or update 0G DA Node repository
if [ -d "$HOME/0g-da-node" ]; then
    echo -e "${GREEN}🔄 Repository already exists. Pulling latest changes...${RESET}"
    cd "$HOME/0g-da-node" && git pull
else
    echo -e "${GREEN}🔽 Cloning 0G DA Node repository...${RESET}"
    git clone https://github.com/0glabs/0g-da-node.git "$HOME/0g-da-node"
    cd "$HOME/0g-da-node"
fi

# Generate BLS Key if it doesn't exist
if [ ! -f bls_key.txt ]; then
    echo "🔑 Generating BLS key..."
    cargo run --bin key-gen > bls_key.txt
fi

# Read and insert BLS key into config.toml
BLS_KEY=$(cat bls_key.txt | tr -d '\n')
sed -i "s|signer_bls_private_key = \"\"|signer_bls_private_key = \"$BLS_KEY\"|g" config.toml
echo "✅ BLS Key successfully added to config.toml!"

# Prompt user for Ethereum private keys
read -p "🔑 Enter your Ethereum Signer Private Key: " SIGNER_ETH_KEY
read -p "🔑 Enter your Ethereum Miner Private Key (Press Enter to use the same as Signer): " MINER_ETH_KEY

# If user presses Enter, use the same key for Miner
if [ -z "$MINER_ETH_KEY" ]; then
    MINER_ETH_KEY="$SIGNER_ETH_KEY"
    echo -e "${GREEN}ℹ️ Using the same key for both Signer & Miner.${RESET}"
fi

# Create config.toml file
echo -e "${GREEN}📝 Creating config.toml file...${RESET}"
cat <<EOF > "$HOME/0g-da-node/config.toml"
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

# Prometheus metrics exporter
prometheus_exporter_address = "0.0.0.0:9000"
EOF
echo -e "${GREEN}✅ Configuration file created.${RESET}"

# Stop and remove existing Docker container if running
if docker ps -a --format '{{.Names}}' | grep -q "0g-da-node"; then
    echo -e "${GREEN}🛑 Stopping and removing existing Docker container...${RESET}"
    docker stop 0g-da-node && docker rm 0g-da-node
fi

# Build and start the Docker container
echo -e "${GREEN}🐳 Building and running the Docker container...${RESET}"
cd "$HOME/0g-da-node"
docker build -t 0g-da-node .
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Docker build failed. Exiting.${RESET}"
    exit 1
fi

docker run -d --name 0g-da-node 0g-da-node

# Display success message
echo -e "${GREEN}🎉 0G DA Node setup complete!${RESET}"
echo -e "👉 Use 'docker logs -f 0g-da-node' to monitor logs."
