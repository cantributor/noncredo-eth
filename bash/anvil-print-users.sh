source ../.env
echo totalUsers $(cast call $ANVIL_USER_REGISTER_PROXY_ADDRESS "totalUsers()(uint32)" --rpc-url $ANVIL_RPC_URL)
echo allNicks $(cast call $ANVIL_USER_REGISTER_PROXY_ADDRESS "allNicks()(string[])" --rpc-url $ANVIL_RPC_URL)

#echo registerMeAs user1
#cast send $USER_REGISTER_PROXY_ADDRESS "registerMeAs(string)(address)" --rpc-url $RPC_URL --private-key $OWNER_PRIVATE_KEY user1
#
#echo getTotalUsers $(cast call $USER_REGISTER_PROXY_ADDRESS "getTotalUsers()(uint256)" --rpc-url $RPC_URL)
#echo getAllNicks $(cast call $USER_REGISTER_PROXY_ADDRESS "getAllNicks()(string[])" --rpc-url $RPC_URL)