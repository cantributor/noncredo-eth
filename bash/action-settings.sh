#!/bin/bash

source _library.sh

initialize "$@"

if [[ -z "$3" ]]; then
  echo "The guess duration is empty"
  exit 1
fi

if [[ -z "$4" ]]; then
  echo "The reveal duration is empty"
  exit 1
fi

forge script ../script/Actions.s.sol:Actions --rpc-url "$NETWORK_NAME" --broadcast -v \
  --private-key "$PRIVATE_KEY" \
  --sig "settings(address,uint256,uint32,uint32)" \
  "$REGISTER_PROXY_ADDRESS" "$2" "$3" "$4"
# above are register-proxy address, private key, guess duration, reveal duration
