source ../.env
RIDDLE_CONTRACT_ADDRESS=$(cast call $ANVIL_REGISTER_PROXY_ADDRESS "riddles(uint256)(address)" 0 --rpc-url $ANVIL_RPC_URL)
echo Riddle contract address = $RIDDLE_CONTRACT_ADDRESS

echo current block number: $(cast block-number --rpc-url $ANVIL_RPC_URL)
echo riddle guess deadline $(cast call $RIDDLE_CONTRACT_ADDRESS "guessDeadline()(uint256)" --rpc-url $ANVIL_RPC_URL)

cast send $RIDDLE_CONTRACT_ADDRESS "reveal(string)(bool)" secret  --rpc-url $ANVIL_RPC_URL --private-key $ANVIL_OWNER_PRIVATE_KEY -vvvv

echo owner balance: $(cast balance 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url $ANVIL_RPC_URL)
echo user1 balance: $(cast balance 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 --rpc-url $ANVIL_RPC_URL)
echo user2 balance: $(cast balance 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC --rpc-url $ANVIL_RPC_URL)