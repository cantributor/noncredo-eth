#!/bin/bash

initialize() {
  source ../.env

  NETWORK_NAME=$1

  if [[ -z "$2" ]]; then
    echo "The user private key is empty"
    exit 1
  fi

  case $1 in
    anvil)
      PRIVATE_KEY=${ANVIL_OWNER_PRIVATE_KEY}
      REGISTER_PROXY_ADDRESS=${ANVIL_REGISTER_PROXY_ADDRESS}
    ;;
    sepolia)
      PRIVATE_KEY=$2
      REGISTER_PROXY_ADDRESS=${SEPOLIA_REGISTER_PROXY_ADDRESS}
    ;;
    *)
      echo "Unsupported network name $1"
      exit 1
    ;;
  esac
}
