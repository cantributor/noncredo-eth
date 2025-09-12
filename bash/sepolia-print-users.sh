source ../.env
echo getTotalUsers $(cast call $SEPOLIA_USER_REGISTER_PROXY_ADDRESS "totalUsers()(uint256)" --rpc-url $SEPOLIA_RPC_URL)
echo getAllNicks $(cast call $SEPOLIA_USER_REGISTER_PROXY_ADDRESS "allNicks()(string[])" --rpc-url $SEPOLIA_RPC_URL)
