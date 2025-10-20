source ../.env
echo -------------------------------------------------------------------------------------------------------------------
echo totalUsers $(cast call $SEPOLIA_REGISTER_PROXY_ADDRESS "totalUsers()(uint32)" --rpc-url $SEPOLIA_RPC_URL)
echo allNicks $(cast call $SEPOLIA_REGISTER_PROXY_ADDRESS "allNicks()(string[])" --rpc-url $SEPOLIA_RPC_URL)
echo -------------------------------------------------------------------------------------------------------------------
echo guess duration \(blocks\) $(cast call $SEPOLIA_REGISTER_PROXY_ADDRESS "guessDurationBlocks()(uint32)" --rpc-url $SEPOLIA_RPC_URL)
echo reveal duration \(blocks\) $(cast call $SEPOLIA_REGISTER_PROXY_ADDRESS "revealDurationBlocks()(uint32)" --rpc-url $SEPOLIA_RPC_URL)
echo register reward \(%\) $(cast call $SEPOLIA_REGISTER_PROXY_ADDRESS "registerRewardPercent()(uint8)" --rpc-url $SEPOLIA_RPC_URL)
echo -------------------------------------------------------------------------------------------------------------------
OWNER_CONTRACT_ADDRESS=$(cast call $SEPOLIA_REGISTER_PROXY_ADDRESS "userOf(string)(address)" owner --rpc-url $SEPOLIA_RPC_URL)
USER1_CONTRACT_ADDRESS=$(cast call $SEPOLIA_REGISTER_PROXY_ADDRESS "userOf(string)(address)" user1 --rpc-url $SEPOLIA_RPC_URL)
USER2_CONTRACT_ADDRESS=$(cast call $SEPOLIA_REGISTER_PROXY_ADDRESS "userOf(string)(address)" user2 --rpc-url $SEPOLIA_RPC_URL)

echo userOf\(\"owner\"\) $OWNER_CONTRACT_ADDRESS
echo userOf\(\"user1\"\) $USER1_CONTRACT_ADDRESS
echo userOf\(\"user2\"\) $USER2_CONTRACT_ADDRESS
echo -------------------------------------------------------------------------------------------------------------------
echo totalRiddles $(cast call $SEPOLIA_REGISTER_PROXY_ADDRESS "totalRiddles()(uint32)" --rpc-url $SEPOLIA_RPC_URL)
echo -------------------------------------------------------------------------------------------------------------------
echo owner balance: $(cast balance $(cast call $OWNER_CONTRACT_ADDRESS "owner()(address)" --rpc-url $SEPOLIA_RPC_URL) --rpc-url $SEPOLIA_RPC_URL)
echo user1 balance: $(cast balance $(cast call $USER1_CONTRACT_ADDRESS "owner()(address)" --rpc-url $SEPOLIA_RPC_URL) --rpc-url $SEPOLIA_RPC_URL)
echo user2 balance: $(cast balance $(cast call $USER2_CONTRACT_ADDRESS "owner()(address)" --rpc-url $SEPOLIA_RPC_URL) --rpc-url $SEPOLIA_RPC_URL)
echo -------------------------------------------------------------------------------------------------------------------
echo current block number: $(cast block-number --rpc-url $SEPOLIA_RPC_URL)
echo -------------------------------------------------------------------------------------------------------------------
