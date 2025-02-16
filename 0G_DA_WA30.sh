#!/bin/bash

# Define colors for output
GREEN="\033[0;32m"
RESET="\033[0m"

echo -e "${GREEN}🚀 Setting up 0G DA Client...${RESET}"

# Ensure Docker group permissions
sudo groupadd docker &>/dev/null || true
sudo usermod -aG docker $USER

# Exit and re-login for Docker group changes to apply
if [ "$EUID" -ne 0 ]; then
    echo -e "${GREEN}🔄 Please log out and log back in for Docker permissions to apply.${RESET}"
fi

# Clean up any existing setup
cd $HOME
rm -rf 0g-da-client

echo -e "${GREEN}🔽 Cloning 0G DA Client repository...${RESET}"
git clone https://github.com/0glabs/0g-da-client.git
cd 0g-da-client

echo -e "${GREEN}🐳 Building Docker image...${RESET}"
docker build -t 0g-da-client -f combined.Dockerfile .

# Prompt for Ethereum Private Key
read -p "🔑 Enter your Ethereum Private Key: " ETH_PRIVATE_KEY

# Create environment file
echo -e "${GREEN}📝 Creating envfile.env...${RESET}"
cat <<EOF > envfile.env
COMBINED_SERVER_CHAIN_RPC=https://evmrpc-testnet.0g.ai
COMBINED_SERVER_PRIVATE_KEY=$ETH_PRIVATE_KEY
ENTRANCE_CONTRACT_ADDR=0x857C0A28A8634614BB2C96039Cf4a20AFF709Aa9

COMBINED_SERVER_RECEIPT_POLLING_ROUNDS=180
COMBINED_SERVER_RECEIPT_POLLING_INTERVAL=1s
COMBINED_SERVER_TX_GAS_LIMIT=2000000
COMBINED_SERVER_USE_MEMORY_DB=true
COMBINED_SERVER_KV_DB_PATH=/runtime/
COMBINED_SERVER_TimeToExpire=2592000
DISPERSER_SERVER_GRPC_PORT=51001
BATCHER_DASIGNERS_CONTRACT_ADDRESS=0x0000000000000000000000000000000000001000
BATCHER_FINALIZER_INTERVAL=20s
BATCHER_CONFIRMER_NUM=3
BATCHER_MAX_NUM_RETRIES_PER_BLOB=3
BATCHER_FINALIZED_BLOCK_COUNT=50
BATCHER_BATCH_SIZE_LIMIT=500
BATCHER_ENCODING_INTERVAL=3s
BATCHER_ENCODING_REQUEST_QUEUE_SIZE=1
BATCHER_PULL_INTERVAL=10s
BATCHER_SIGNING_INTERVAL=3s
BATCHER_SIGNED_PULL_INTERVAL=20s
BATCHER_EXPIRATION_POLL_INTERVAL=3600
BATCHER_ENCODER_ADDRESS=DA_ENCODER_SERVER
BATCHER_ENCODING_TIMEOUT=300s
BATCHER_SIGNING_TIMEOUT=60s
BATCHER_CHAIN_READ_TIMEOUT=12s
BATCHER_CHAIN_WRITE_TIMEOUT=13s
EOF

echo -e "${GREEN}✅ Configuration file created.${RESET}"

# Run the container
echo -e "${GREEN}🐳 Starting 0G DA Client container...${RESET}"
docker run -d --env-file envfile.env --name 0g-da-client --restart always -v ./run:/runtime -p 51001:51001 0g-da-client combined

echo -e "${GREEN}🎉 0G DA Client setup complete!${RESET}"
echo -e "👉 Use 'docker logs -f 0g-da-client' to monitor logs."
