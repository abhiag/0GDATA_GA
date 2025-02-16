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

# Navigate to 0G DA Node directory
echo "📂 Changing to the 0G DA Node directory..."
cd ~/0g-da-node || { echo "❌ Error: ~/0g-da-node directory not found!"; exit 1; }

# Check if Dockerfile exists
if [ ! -f Dockerfile ]; then
    echo "❌ Error: Dockerfile not found in ~/0g-da-node!"
    exit 1
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

# Install dependencies if missing
echo "🔄 Checking and installing dependencies..."
sudo apt update -y
sudo apt install -y curl wget jq unzip screen docker.io

# Build the Docker image
echo "🔨 Building Docker image..."
docker build -t 0g-da-node . || { echo "❌ Error: Docker build failed!"; exit 1; }

# Run the Docker container
echo "🚀 Starting 0G DA Node..."
docker run -d --name 0g-da-node 0g-da-node

# Verify the Node is Running
echo "🔍 Verifying the node status..."
docker logs -f 0g-da-node
