# Set vars
read -p "Enter node name: " MONIKER
echo 'export MONIKER="'$MONIKER'"' >> $HOME/.bash_profile
echo 'export CHAIN_ID="zgtendermint_16600-2"' >> ~/.bash_profile
echo 'export WALLET_NAME="wallet"' >> ~/.bash_profile
echo 'export RPC_PORT="26657"' >> ~/.bash_profile
source $HOME/.bash_profile

# Update and install dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install curl tar wget clang pkg-config protobuf-compiler libssl-dev jq build-essential protobuf-compiler bsdmainutils git make ncdu gcc git jq chrony liblz4-tool -y snapd

# Install 0gchaind
git clone -b v0.2.3 https://github.com/0glabs/0g-chain.git
./0g-chain/networks/testnet/install.sh
source ~/.profile

# Initialize node
0gchaind init $MONIKER --chain-id $CHAIN_ID
0gchaind config chain-id $CHAIN_ID
0gchaind config node tcp://localhost:$RPC_PORT
0gchaind config keyring-backend os

# Download and validate genesis file
rm $HOME/.0gchain/config/genesis.json
wget https://github.com/0glabs/0g-chain/releases/download/v0.2.3/genesis.json -O $HOME/.0gchain/config/genesis.json
0gchaind validate-genesis

# Configure seeds and peers
SEEDS="81987895a11f6689ada254c6b57932ab7ed909b6@54.241.167.190:26656,010fb4de28667725a4fef26cdc7f9452cc34b16d@54.176.175.48:26656,e9b4bc203197b62cc7e6a80a64742e752f4210d5@54.193.250.204:26656,68b9145889e7576b652ca68d985826abd46ad660@18.166.164.232:26656"
sed -i.bak -e "s/^seeds *=.*/seeds = \"${SEEDS}\"/" $HOME/.0gchain/config/config.toml

PEERS="6dbb0450703d156d75db57dd3e51dc260a699221@152.53.47.155:13456,1bf93ac820773970cf4f46a479ab8b8206de5f60@62.171.185.81:12656,df4cc52fa0fcdd5db541a28e4b5a9c6ce1076ade@37.60.246.110:13456,66d59739b6b4ff0658e63832a5bbeb29e5259742@144.76.79.209:26656,76cc5b9beaff9f33dc2a235e80fe2d47448463a7@95.216.114.170:26656,adc616f440155f4e5c2bf748e9ac3c9e24bf78ac@51.161.13.62:26656,cd662c11f7b4879b3861a419a06041c782f1a32d@89.116.24.249:26656,40cf5c7c11931a4fdab2b721155cc236dfe7a809@84.46.255.133:12656,11945ced69c3448adeeba49355703984fcbc3a1a@37.27.130.146:26656,c02bf872d61f5dd04e877105ded1bd03243516fb@65.109.25.252:12656,d5e294d6d5439f5bd63d1422423d7798492e70fd@77.237.232.146:26656,386c82b09e0ec6a68e653a5d6c57f766ae73e0df@194.163.183.208:26656,4eac33906b2ba13ab37d0e2fe8fc5801e75f25a0@154.38.168.168:13456,c96b65a5b02081e3111b8b38cd7f5df76c7f9404@185.182.185.160:26656,48e3cab55ba7a1bc8ea940586e4718a857de84c4@178.63.4.186:26656"
sed -i "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.0gchain/config/config.toml

# Set minimum gas price
sed -i "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0ua0gi\"/" $HOME/.0gchain/config/app.toml

# Create or import an account
read -p "Do you want to create a new wallet or import an existing one? (create/import): " WALLET_ACTION

if [[ "$WALLET_ACTION" == "create" ]]; then
    # Create a new wallet
    0gchaind keys add $WALLET_NAME --eth
    echo "Your wallet has been created. Please securely store the following private key:"
    0gchaind keys unsafe-export-eth-key $WALLET_NAME
elif [[ "$WALLET_ACTION" == "import" ]]; then
    # Import an existing wallet
    read -p "Enter your private key: " PRIVATE_KEY
    echo "$PRIVATE_KEY" | 0gchaind keys unsafe-import-eth-key $WALLET_NAME --eth
    echo "Wallet imported successfully."
else
    echo "Invalid option. Exiting."
    exit 1
fi

# Create service
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

# Start service
sudo systemctl daemon-reload
sudo systemctl enable 0gd
sudo systemctl restart 0gd

# Optimization
export GOGC=900
export GOMEMLIMIT=24000MiB

# Faucet reminder
echo "================================================="
echo -e "\e[1m\e[32mBefore creating a validator, make sure you have testnet tokens from the faucet.\e[0m"
echo -e "\e[1m\e[32mFaucet: https://faucet.0g.ai\e[0m"
echo "================================================="
sleep 5

# Check if the node is fully synced
SYNC_STATUS=$(0gchaind status | jq .SyncInfo.catching_up)
if [[ "$SYNC_STATUS" == "false" ]]; then
    echo -e "\e[1m\e[32mNode is fully synced.\e[0m"
else
    echo -e "\e[1m\e[31mNode is still syncing. Please wait until it is fully synced.\e[0m"
    exit 1
fi

# Check wallet balance
WALLET_BALANCE=$(0gchaind q bank balances $(0gchaind keys show $WALLET_NAME -a) --node tcp://localhost:$RPC_PORT --output json | jq -r '.balances[0].amount')
if [[ -z "$WALLET_BALANCE" || "$WALLET_BALANCE" -lt 1000000 ]]; then
    echo -e "\e[1m\e[31mInsufficient balance. Please get testnet tokens from the faucet: https://faucet.0g.ai\e[0m"
    exit 1
else
    echo -e "\e[1m\e[32mWallet balance: ${WALLET_BALANCE}ua0gi\e[0m"
fi

# Create validator
read -p "Do you want to create a validator now? (yes/no): " CREATE_VALIDATOR
if [[ "$CREATE_VALIDATOR" == "yes" ]]; then
    echo -e "\e[1m\e[32mCreating validator...\e[0m"
    0gchaind tx staking create-validator \
      --amount=1000000ua0gi \
      --pubkey=$(0gchaind tendermint show-validator) \
      --moniker=$MONIKER \
      --chain-id=$CHAIN_ID \
      --commission-rate=0.05 \
      --commission-max-rate=0.10 \
      --commission-max-change-rate=0.01 \
      --min-self-delegation=1 \
      --from=$WALLET_NAME \
      --identity="" \
      --website="" \
      --details="NodesRunner number 1!" \
      --gas=auto \
      --gas-adjustment=1.4 \
      -y
    echo -e "\e[1m\e[32mValidator created successfully!\e[0m"
else
    echo -e "\e[1m\e[33mValidator creation skipped.\e[0m"
fi

echo '=============== SETUP FINISHED ==================='
echo -e 'View the logs from the running service: sudo journalctl -u 0gd -f -o cat'
echo -e "Check the node is running: sudo systemctl status 0gd.service"
echo -e "Stop your node: sudo systemctl stop 0gd.service"
echo -e "Start your node: sudo systemctl start 0gd.service"