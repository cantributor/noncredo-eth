USER_REGISTER_PROXY_ADDRESS=0x8A791620dd6260079BF849Dc5567aDC3F2FdC318
RPC_URL=127.0.0.1:8545
OWNER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

echo getTotalUsers $(cast call $USER_REGISTER_PROXY_ADDRESS "getTotalUsers()(uint256)" --rpc-url $RPC_URL)
echo getAllNicks $(cast call $USER_REGISTER_PROXY_ADDRESS "getAllNicks()(string[])" --rpc-url $RPC_URL)

#echo registerMeAs user1
#cast send $USER_REGISTER_PROXY_ADDRESS "registerMeAs(string)(address)" --rpc-url $RPC_URL --private-key $OWNER_PRIVATE_KEY user1
#
#echo getTotalUsers $(cast call $USER_REGISTER_PROXY_ADDRESS "getTotalUsers()(uint256)" --rpc-url $RPC_URL)
#echo getAllNicks $(cast call $USER_REGISTER_PROXY_ADDRESS "getAllNicks()(string[])" --rpc-url $RPC_URL)