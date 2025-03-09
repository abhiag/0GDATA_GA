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

# Function to increase connection limits
increase_connection_limits() {
    echo -e "\e[1m\e[32mIncreasing connection limits...\e[0m"
    sed -i 's/^max_num_inbound_peers *=.*/max_num_inbound_peers = 100/' $HOME/.0gchain/config/config.toml
    sed -i 's/^max_num_outbound_peers *=.*/max_num_outbound_peers = 100/' $HOME/.0gchain/config/config.toml
    echo -e "\e[1m\e[32mConnection limits increased successfully.\e[0m"
}

# Function to install the node
install_node() {
    echo -e "\e[1m\e[32m1. Updating packages... \e[0m" && sleep 1
    sudo apt update && sudo apt upgrade -y

    echo -e "\e[1m\e[32m2. Installing dependencies... \e[0m" && sleep 1
    sudo apt install curl tar wget clang pkg-config protobuf-compiler libssl-dev jq build-essential protobuf-compiler bsdmainutils git make ncdu gcc git jq chrony liblz4-tool -y snapd

    echo -e "\e[1m\e[32m3. Installing Go... \e[0m" && sleep 1
    cd $HOME && \
    ver="1.22.0" && \
    wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz" && \
    sudo rm -rf /usr/local/go && \
    sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz" && \
    rm "go$ver.linux-amd64.tar.gz" && \
    echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> $HOME/.bash_profile && \
    source $HOME/.bash_profile && \
    go version

    echo -e "\e[1m\e[32m4. Downloading and building binaries... \e[0m" && sleep 1
    git clone -b v0.2.3 https://github.com/0glabs/0g-chain.git
    cd 0g-chain
    make install
    0gchaind version

    echo -e "\e[1m\e[32m5. Initializing node... \e[0m" && sleep 1
    read -p "Enter node name: " MONIKER
    0gchaind init $MONIKER --chain-id zgtendermint_16600-2
    0gchaind config chain-id zgtendermint_16600-2
    0gchaind config node tcp://localhost:26657
    0gchaind config keyring-backend os

    echo -e "\e[1m\e[32m6. Downloading genesis file... \e[0m" && sleep 1
    rm $HOME/.0gchain/config/genesis.json
    wget https://github.com/0glabs/0g-chain/releases/download/v0.2.3/genesis.json -O $HOME/.0gchain/config/genesis.json

    echo -e "\e[1m\e[32m7. Configuring seeds and peers... \e[0m" && sleep 1
    SEEDS="81987895a11f6689ada254c6b57932ab7ed909b6@54.241.167.190:26656,010fb4de28667725a4fef26cdc7f9452cc34b16d@54.176.175.48:26656,e9b4bc203197b62cc7e6a80a64742e752f4210d5@54.193.250.204:26656,68b9145889e7576b652ca68d985826abd46ad660@18.166.164.232:26656"
    sed -i.bak -e "s/^seeds *=.*/seeds = \"${SEEDS}\"/" $HOME/.0gchain/config/config.toml

    PEERS="6dbb0450703d156d75db57dd3e51dc260a699221@152.53.47.155:13456,1bf93ac820773970cf4f46a479ab8b8206de5f60@62.171.185.81:12656,df4cc52fa0fcdd5db541a28e4b5a9c6ce1076ade@37.60.246.110:13456,66d59739b6b4ff0658e63832a5bbeb29e5259742@144.76.79.209:26656,76cc5b9beaff9f33dc2a235e80fe2d47448463a7@95.216.114.170:26656,adc616f440155f4e5c2bf748e9ac3c9e24bf78ac@51.161.13.62:26656,cd662c11f7b4879b3861a419a06041c782f1a32d@89.116.24.249:26656,40cf5c7c11931a4fdab2b721155cc236dfe7a809@84.46.255.133:12656,11945ced69c3448adeeba49355703984fcbc3a1a@37.27.130.146:26656,c02bf872d61f5dd04e877105ded1bd03243516fb@65.109.25.252:12656,d5e294d6d5439f5bd63d1422423d7798492e70fd@77.237.232.146:26656,386c82b09e0ec6a68e653a5d6c57f766ae73e0df@194.163.183.208:26656,4eac33906b2ba13ab37d0e2fe8fc5801e75f25a0@154.38.168.168:13456,c96b65a5b02081e3111b8b38cd7f5df76c7f9404@185.182.185.160:26656,48e3cab55ba7a1bc8ea940586e4718a857de84c4@178.63.4.186:26656"
    sed -i "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.0gchain/config/config.toml

    echo -e "\e[1m\e[32m8. Setting minimum gas price... \e[0m" && sleep 1
    sed -i "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0ua0gi\"/" $HOME/.0gchain/config/app.toml

    echo -e "\e[1m\e[32m9. Creating service... \e[0m" && sleep 1
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

    echo -e "\e[1m\e[32m10. Starting service... \e[0m" && sleep 1
    sudo systemctl daemon-reload
    sudo systemctl enable 0gd
    sudo systemctl start 0gd

    echo -e "\e[1m\e[32mNode installation completed!\e[0m"
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
    sudo systemctl status 0gd
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
    echo "4. Uninstall Node"
    echo "5. Check Node Status"
    echo "6. Setup Validator"
    echo "7. Exit"
    echo "================================================="
    read -p "Enter your choice: " CHOICE

    case $CHOICE in
        1) install_node ;;
        2) restart_node ;;
        3) stop_node ;;
        4) uninstall_node ;;
        5) check_status ;;
        6) setup_validator ;;
        7) break ;;
        *) echo -e "\e[1m\e[31mInvalid choice. Please try again.\e[0m" ;;
    esac
done