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
    cd "$HOME/0g-da-node"
    git pull origin main || { echo -e "${RED}❌ Failed to update repository. Exiting.${RESET}"; exit 1; }
else
    echo -e "${GREEN}🔽 Cloning 0G DA Node repository...${RESET}"
    git clone https://github.com/0glabs/0g-da-node.git "$HOME/0g-da-node"
    cd "$HOME/0g-da-node"
fi

# Generate BLS private key (if not already generated)
if [ ! -f "bls_key.txt" ]; then
    echo -e "${GREEN}🔑 Generating BLS Private Key...${RESET}"
    cargo run --bin key-gen > bls_key.txt 2>/dev/null
    sleep 2  # Give it a moment to write the file
fi

# Check if BLS key file exists
if [ ! -f "bls_key.txt" ]; then
    echo -e "${RED}❌ Failed to generate BLS Private Key. Exiting.${RESET}"
    exit 1
fi

# Extract BLS Private Key
BLS_PRIVATE_KEY=$(cat bls_key.txt | tr -d '\n')

if [[ -z "$BLS_PRIVATE_KEY" ]]; then
    echo -e "${RED}❌ BLS Private Key extraction failed. Exiting.${RESET}"
    exit 1
fi

echo -e "${GREEN}✅ BLS Private Key successfully extracted: $BLS_PRIVATE_KEY${RESET}"

# Prompt user for Ethereum Private Key (used for both Signer & Miner)
read -p "🔑 Enter your Ethereum Private Key (used for both Signer & Miner): " ETH_PRIVATE_KEY

# Use the same key for both signer and miner
SIGNER_ETH_KEY="$ETH_PRIVATE_KEY"
MINER_ETH_KEY="$ETH_PRIVATE_KEY"

echo -e "${GREEN}✅ Using the same key for both Signer & Miner.${RESET}"

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

# Prometheus exporter address
prometheus_exporter_address = "0.0.0.0:9200"
EOF

echo -e "${GREEN}✅ Configuration file created.${RESET}"

# Read and insert BLS key into config.toml
BLS_PRIVATE_KEY=$(cat bls_key.txt | tr -d '\n')
sed -i "s|signer_bls_private_key = \"\"|signer_bls_private_key = \"$BLS_PRIVATE_KEY\"|g" config.toml
echo "✅ BLS Key successfully added to config.toml!"

# **Verify that BLS key is correctly inserted**
if grep -q "signer_bls_private_key = \"$BLS_PRIVATE_KEY\"" config.toml; then
    echo -e "${GREEN}✅ BLS Private Key successfully written to config.toml.${RESET}"
else
    echo -e "${RED}❌ BLS Private Key insertion failed! Exiting.${RESET}"
    exit 1
fi

# Stop and remove existing container (if running)
if docker ps -a --format '{{.Names}}' | grep -q "0g-da-node"; then
    echo -e "${GREEN}🛑 Stopping and removing existing container...${RESET}"
    docker stop 0g-da-node && docker rm 0g-da-node
fi

# Build and start the Docker container
echo -e "${GREEN}🐳 Building and running the Docker container...${RESET}"
docker build -t 0g-da-node .
docker run -d --name 0g-da-node 0g-da-node

# Display success message
echo -e "${GREEN}🎉 0G DA Node setup complete!${RESET}"
echo -e "👉 Use 'docker logs -f 0g-da-node' to monitor logs."
