#!/bin/bash

source _library.sh

initialize "$@"

if [[ -z "$3" ]]; then
  echo "The user nick is empty"
  exit 1
fi

forge script ../script/Actions.s.sol:Actions --rpc-url "$NETWORK_NAME" --broadcast -v \
  --private-key "$PRIVATE_KEY" \
  --sig "register(address,uint256,string)" \
  "$REGISTER_PROXY_ADDRESS" "$2" "$3" # register-proxy address, private key and nick params
