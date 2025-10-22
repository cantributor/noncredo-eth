source ../.env
echo -------------------------------------------------------------------------------------------------------------------
echo totalUsers $(cast call $ANVIL_REGISTER_PROXY_ADDRESS "totalUsers()(uint32)" --rpc-url $ANVIL_RPC_URL)
echo -------------------------------------------------------------------------------------------------------------------
echo guess duration \(blocks\) $(cast call $ANVIL_REGISTER_PROXY_ADDRESS "guessDurationBlocks()(uint32)" --rpc-url $ANVIL_RPC_URL)
echo reveal duration \(blocks\) $(cast call $ANVIL_REGISTER_PROXY_ADDRESS "revealDurationBlocks()(uint32)" --rpc-url $ANVIL_RPC_URL)
echo register reward \(%\) $(cast call $ANVIL_REGISTER_PROXY_ADDRESS "registerRewardPercent()(uint8)" --rpc-url $ANVIL_RPC_URL)
echo -------------------------------------------------------------------------------------------------------------------
OWNER_CONTRACT_ADDRESS=$(cast call $ANVIL_REGISTER_PROXY_ADDRESS "userOf(string)(address)" owner --rpc-url $ANVIL_RPC_URL)
USER1_CONTRACT_ADDRESS=$(cast call $ANVIL_REGISTER_PROXY_ADDRESS "userOf(string)(address)" user1 --rpc-url $ANVIL_RPC_URL)
USER2_CONTRACT_ADDRESS=$(cast call $ANVIL_REGISTER_PROXY_ADDRESS "userOf(string)(address)" user2 --rpc-url $ANVIL_RPC_URL)

echo userOf\(\"owner\"\) $OWNER_CONTRACT_ADDRESS
echo userOf\(\"user1\"\) $USER1_CONTRACT_ADDRESS
echo userOf\(\"user2\"\) $USER2_CONTRACT_ADDRESS
echo -------------------------------------------------------------------------------------------------------------------
echo totalRiddles $(cast call $ANVIL_REGISTER_PROXY_ADDRESS "totalRiddles()(uint32)" --rpc-url $ANVIL_RPC_URL)
echo -------------------------------------------------------------------------------------------------------------------
echo owner balance: $(cast balance $(cast call $OWNER_CONTRACT_ADDRESS "owner()(address)" --rpc-url $ANVIL_RPC_URL) --rpc-url $ANVIL_RPC_URL)
echo user1 balance: $(cast balance $(cast call $USER1_CONTRACT_ADDRESS "owner()(address)" --rpc-url $ANVIL_RPC_URL) --rpc-url $ANVIL_RPC_URL)
echo user2 balance: $(cast balance $(cast call $USER2_CONTRACT_ADDRESS "owner()(address)" --rpc-url $ANVIL_RPC_URL) --rpc-url $ANVIL_RPC_URL)
echo -------------------------------------------------------------------------------------------------------------------
echo current block number: $(cast block-number --rpc-url $ANVIL_RPC_URL)
echo -------------------------------------------------------------------------------------------------------------------
