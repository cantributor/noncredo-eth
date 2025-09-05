include .env

build:
	forge clean && forge build

test: build
	forge test

anvil-deploy: build
	forge script script/Deploy.s.sol:DeployScript --rpc-url anvil --broadcast -v \
      --private-key ${ANVIL_OWNER_PRIVATE_KEY}

sepolia-deploy: test
	forge script script/Deploy.s.sol:DeployScript --rpc-url sepolia --broadcast -vv --verify \
      --private-key ${SOLIDITY_STUDENT_PRIVATE_KEY}

anvil-create-users: build
	forge script script/ScenarioCreateUsers.s.sol:ScenarioCreateUsers --rpc-url anvil --broadcast -v \
      --private-key ${ANVIL_OWNER_PRIVATE_KEY} \
      --sig "run(address,uint256,uint256)" \
      ${ANVIL_USER_REGISTER_PROXY_ADDRESS} \
      ${ANVIL_OWNER_PRIVATE_KEY} \
      ${ANVIL_USER_PRIVATE_KEY}

sepolia-create-users: build
	forge script script/ScenarioCreateUsers.s.sol:ScenarioCreateUsers --rpc-url sepolia --broadcast -v \
      --private-key ${ANVIL_OWNER_PRIVATE_KEY} \
      --sig "run(address,uint256,uint256)" \
      ${SEPOLIA_USER_REGISTER_PROXY_ADDRESS} \
      ${SOLIDITY_STUDENT_PRIVATE_KEY} \
      ${SOLIDITY_STUDENT_2_PRIVATE_KEY}

