#!/bin/bash

source _library.sh

initialize "$@"

forge script ../script/Actions.s.sol:Actions --rpc-url "$NETWORK_NAME" -v \
  --private-key "$PRIVATE_KEY" \
  --sig "printFullReport(address)" \
  "$REGISTER_PROXY_ADDRESS" # register-proxy address
