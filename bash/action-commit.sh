#!/bin/bash

source _library.sh

initialize "$@"

if [[ -z "$3" ]]; then
  echo "The riddle statement is empty"
  exit 1
fi

if [[ -z "$4" ]]; then
  echo "The User bet is empty"
  exit 1
fi

if [[ -z "$5" ]]; then
  echo "The Riddle solution (Credo/NonCredo) is empty"
  exit 1
fi

if [[ -z "$6" ]]; then
  echo "The user secret key is empty"
  exit 1
fi

forge script ../script/Actions.s.sol:Actions --rpc-url "$NETWORK_NAME" --broadcast -v \
  --private-key "$PRIVATE_KEY" \
  --sig "commit(address,uint256,string,uint256,bool,string)" \
  "$REGISTER_PROXY_ADDRESS" "$2" "$3" "$4" "$5" "$6"
# above are register-proxy address, private key, riddle statement, placed bet, Credo/NonCredo, user secret key
