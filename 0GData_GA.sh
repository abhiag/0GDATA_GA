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

# Clone 0G DA Node repository
echo -e "${GREEN}🔽 Cloning 0G DA Node repository...${RESET}"
git clone https://github.com/0glabs/0g-da-node.git ~/0g-da-node || cd ~/0g-da-node && git pull
cd ~/0g-da-node

# Stop & Remove Existing Container (if any)
if docker ps -a --format '{{.Names}}' | grep -q "0g-da-node"; then
    echo -e "${GREEN}🛑 Stopping existing 0G DA Node container...${RESET}"
    docker stop 0g-da-node && docker rm 0g-da-node
fi

# Generate BLS private key (if needed)
if [ ! -f bls_key.txt ]; then
    echo -e "${GREEN}🔑 Generating BLS Private Key...${RESET}"
    cargo run --bin key-gen > bls_key.txt
fi
BLS_PRIVATE_KEY=$(grep -oP '(?<=Private key: ).*' bls_key.txt | tr -d '\n')

if [ -z "$BLS_PRIVATE_KEY" ]; then
    echo -e "${GREEN}❌ Failed to generate BLS Private Key. Exiting.${RESET}"
    exit 1
fi

echo -e "${GREEN}✅ BLS Private Key: $BLS_PRIVATE_KEY ${RESET}"

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

# Prometheus exporter address (Fixing missing key issue)
prometheus_exporter_address = "0.0.0.0:9000"

# Enable data availability sampling
enable_das = "true"
EOF

echo -e "${GREEN}✅ Configuration file created.${RESET}"

# Build and start the Docker container
echo -e "${GREEN}🐳 Building and running the Docker container...${RESET}"
docker build -t 0g-da-node . && docker run -d --name 0g-da-node 0g-da-node

if [ $? -ne 0 ]; then
    echo -e "${GREEN}❌ Docker failed to build or run. Check logs for details.${RESET}"
    exit 1
fi

echo -e "${GREEN}🎉 0G DA Node setup complete!${RESET}"
echo -e "👉 Use 'docker logs -f 0g-da-node' to monitor logs."
