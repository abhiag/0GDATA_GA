#!/bin/bash

# Function to open necessary ports
open_ports() {
    echo -e "\e[1m\e[32mOpening necessary ports...\e[0m"
    sudo ufw allow 26656  # P2P port
    sudo ufw allow 26657  # RPC port
    sudo ufw allow 1317   # REST API port (if applicable)
    sudo ufw reload
    echo -e "\e[1m\e[32mPorts opened successfully.\e[0m"
}

# Function to install the node
install_node() {
    echo -e "\e[1m\e[32m1. Updating packages... \e[0m" && sleep 1
    sudo apt update && sudo apt upgrade -y

    echo -e "\e[1m\e[32m2. Installing dependencies... \e[0m" && sleep 1
    sudo apt install curl tar wget clang pkg-config protobuf-compiler libssl-dev jq build-essential protobuf-compiler bsdmainutils git make ncdu gcc git jq chrony liblz4-tool -y

    echo -e "\e[1m\e[32m3. Installing Go... \e[0m" && sleep 1
    cd $HOME && \
    ver="1.22.0" && \
    wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz" && \
    sudo rm -rf /usr/local/go && \
    sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz" && \
    rm "go$ver.linux-amd64.tar.gz" && \
    echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> $HOME/.bashrc && \
    source $HOME/.bashrc && \
    go version

    echo -e "\e[1m\e[32m4. Downloading and building binaries... \e[0m" && sleep 1
    git clone -b v0.2.3 https://github.com/0glabs/0g-chain.git
    cd 0g-chain
    make install || { echo -e "\e[1m\e[31mFailed to build binaries. Exiting...\e[0m"; exit 1; }
    0gchaind version

    echo -e "\e[1m\e[32m5. Initializing node... \e[0m" && sleep 1
    read -p "Enter node name (default: 0g-node): " MONIKER
    MONIKER=${MONIKER:-0g-node}
    0gchaind init $MONIKER --chain-id zgtendermint_16600-2
    0gchaind config chain-id zgtendermint_16600-2
    0gchaind config node tcp://localhost:26657
    0gchaind config keyring-backend os

    echo -e "\e[1m\e[32m6. Downloading genesis file... \e[0m" && sleep 1
    rm $HOME/.0gchain/config/genesis.json
    wget https://github.com/0glabs/0g-chain/releases/download/v0.2.3/genesis.json -O $HOME/.0gchain/config/genesis.json || { echo -e "\e[1m\e[31mFailed to download genesis file. Exiting...\e[0m"; exit 1; }

    echo -e "\e[1m\e[32m7. Configuring seeds... \e[0m" && sleep 1
    SEEDS="81987895a11f6689ada254c6b57932ab7ed909b6@54.241.167.190:26656,010fb4de28667725a4fef26cdc7f9452cc34b16d@54.176.175.48:26656,e9b4bc203197b62cc7e6a80a64742e752f4210d5@54.193.250.204:26656,68b9145889e7576b652ca68d985826abd46ad660@18.166.164.232:26656"
    sed -i.bak -e "s/^seeds *=.*/seeds = \"${SEEDS}\"/" $HOME/.0gchain/config/config.toml

    echo -e "\e[1m\e[32m8. Updating persistent peers dynamically... \e[0m" && sleep 1
    update_peers

    echo -e "\e[1m\e[32m9. Increasing peer limits... \e[0m" && sleep 1
    sed -i 's/^max_num_inbound_peers *=.*/max_num_inbound_peers = 100/' $HOME/.0gchain/config/config.toml
    sed -i 's/^max_num_outbound_peers *=.*/max_num_outbound_peers = 100/' $HOME/.0gchain/config/config.toml

    echo -e "\e[1m\e[32m10. Setting minimum gas price... \e[0m" && sleep 1
    sed -i "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0ua0gi\"/" $HOME/.0gchain/config/app.toml

    echo -e "\e[1m\e[32m11. Creating service... \e[0m" && sleep 1
    if ! command -v 0gchaind &> /dev/null; then
        echo -e "\e[1m\e[31m0gchaind binary not found. Exiting...\e[0m"
        exit 1
    fi
    sudo tee /etc/systemd/system/0gd.service > /dev/null <<EOF
[Unit]
Description=0G Node
After=network.target

[Service]
User=$USER
Type=simple
ExecStart=$(which 0gchaind) start --home $HOME/.0gchain
Restart=on-failure
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    echo -e "\e[1m\e[32m12. Starting service... \e[0m" && sleep 1
    sudo systemctl daemon-reload
    sudo systemctl enable 0gd
    sudo systemctl start 0gd

    echo -e "\e[1m\e[32mNode installation completed!\e[0m"
}

# Function to update persistent peers dynamically
update_peers() {
    echo -e "\e[1m\e[32mFetching live peers... \e[0m" && sleep 1
    PEERS=$(curl -s -X POST https://16600.rpc.thirdweb.com -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"net_info","params":[],"id":1}' | jq -r '.result.peers[] | select(.connection_status.SendMonitor.Active == true) | "\(.node_info.id)@\(if .node_info.listen_addr | contains("0.0.0.0") then .remote_ip + ":" + (.node_info.listen_addr | sub("tcp://0.0.0.0:"; "")) else .node_info.listen_addr | sub("tcp://"; "") end)"' | tr '\n' ',' | sed 's/,$//' | awk '{print "\"" $0 "\""}') || PEERS="$SEEDS"

    if [ -z "$PEERS" ]; then
        echo -e "\e[1m\e[31mFailed to fetch peers. Using default seeds as persistent peers.\e[0m"
        PEERS="$SEEDS"
    fi

    echo -e "\e[1m\e[32mUpdating persistent peers in config.toml... \e[0m" && sleep 1
    sed -i "s/^persistent_peers *=.*/persistent_peers = $PEERS/" $HOME/.0gchain/config/config.toml

    if [ $? -eq 0 ]; then
        echo -e "\e[1m\e[32mPersistent peers updated successfully!\e[0m"
    else
        echo -e "\e[1m\e[31mFailed to update persistent peers.\e[0m"
    fi
}

# Function to monitor logs
monitor_logs() {
    echo -e "\e[1m\e[32mMonitoring node logs... \e[0m" && sleep 1
    journalctl -u 0gd -f
}

# Function to restart the node
restart_node() {
    echo -e "\e[1m\e[32mRestarting node...\e[0m"
    sudo systemctl restart 0gd
    echo -e "\e[1m\e[32mNode restarted successfully.\e[0m"
}

# Function to stop the node
stop_node() {
    echo -e "\e[1m\e[32mStopping node...\e[0m"
    sudo systemctl stop 0gd
    echo -e "\e[1m\e[32mNode stopped successfully.\e[0m"
}

# Function to uninstall the node
uninstall_node() {
    echo -e "\e[1m\e[32mUninstalling node...\e[0m"
    sudo systemctl stop 0gd
    sudo systemctl disable 0gd
    sudo rm /etc/systemd/system/0gd.service
    rm -rf $HOME/.0gchain
    sudo rm /usr/local/bin/0gchaind
    echo -e "\e[1m\e[32mNode uninstalled successfully.\e[0m"
}

# Function to check node status
check_status() {
    echo -e "\e[1m\e[32mChecking node status...\e[0m"
    sudo systemctl status 0gd --no-pager
}

check_peers_and_status() {
    echo -e "\e[1m\e[32mChecking connected peers and log sync height...\e[0m"
    echo -e "\e[1m\e[32mPress Ctrl+C to exit.\e[0m"

    while true; do
        # Send JSON-RPC request to the node
        response=$(curl -s -X POST http://localhost:5678 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"zgs_getStatus","params":[],"id":1}')

        # Extract logSyncHeight and connectedPeers from the response
        logSyncHeight=$(echo "$response" | jq -r '.result.logSyncHeight')
        connectedPeers=$(echo "$response" | jq -r '.result.connectedPeers')

        # Display the results with colored output
        echo -e "logSyncHeight: \033[32m$logSyncHeight\033[0m, connectedPeers: \033[34m$connectedPeers\033[0m"

        # Wait for 5 seconds before the next check
        sleep 5
    done
}

# Function to setup validator
setup_validator() {
    echo -e "\e[1m\e[32mSetting up validator...\e[0m"
    read -p "Enter your wallet name: " WALLET_NAME
    read -p "Enter your validator name: " MONIKER
    read -p "Enter your validator details: " DETAILS
    read -p "Enter your website: " WEBSITE
    read -p "Enter your identity (keybase key): " IDENTITY

    0gchaind tx staking create-validator \
      --amount=1000000ua0gi \
      --pubkey=$(0gchaind tendermint show-validator) \
      --moniker=$MONIKER \
      --chain-id=zgtendermint_16600-2 \
      --commission-rate=0.05 \
      --commission-max-rate=0.10 \
      --commission-max-change-rate=0.01 \
      --min-self-delegation=1 \
      --from=$WALLET_NAME \
      --identity="$IDENTITY" \
      --website="$WEBSITE" \
      --details="$DETAILS" \
      --gas=auto \
      --gas-adjustment=1.4 \
      -y
    echo -e "\e[1m\e[32mValidator setup completed!\e[0m"
}

# Interactive menu
while true; do
    echo "================================================="
    echo "1. Install Node"
    echo "2. Restart Node"
    echo "3. Stop Node"
    echo "5. Check Node Status"
    echo "6. Monitor Node Logs"
    echo "7. Check Peers Status"
    echo "================================================="
    echo "8. Setup Your Node As Validator"
    echo "9. Update Peers"
    echo "================================================="
    echo "10. Uninstall Node"
    echo "================================================="
    echo "0. EXIT"
    echo "================================================="
    read -p "Enter your choice: " CHOICE

    case $CHOICE in
        1) install_node ;;
        2) restart_node ;;
        3) stop_node ;;
        10) uninstall_node ;;
        5) check_status ;;
        8) setup_validator ;;
        7) check_peers_and_status ;;
        6) monitor_logs ;;
        9) update_peers ;;
        0) break ;;
        *) echo -e "\e[1m\e[31mInvalid choice. Please try again.\e[0m" ;;
    esac
    read -rp "Press Enter to return to the main menu..."
done
