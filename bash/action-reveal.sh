#!/bin/bash

source _library.sh

initialize "$@"

if [[ -z "$3" ]]; then
  echo "The riddle index is empty"
  exit 1
fi

if [[ -z "$4" ]]; then
  echo "The user secret key is empty"
  exit 1
fi

forge script ../script/Actions.s.sol:Actions --rpc-url "$NETWORK_NAME" --broadcast -v \
  --private-key "$PRIVATE_KEY" \
  --sig "reveal(address,uint256,uint32,string)" \
  "$REGISTER_PROXY_ADDRESS" "$2" "$3" "$4"
# above are register-proxy address, private key, riddle index, user secret key
