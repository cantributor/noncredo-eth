include .env

build:
	forge fmt && forge build

build-with-optimization:
	forge fmt && forge clean && forge cache clean && forge build --optimize --optimizer-runs 100 --via-ir

test: build
	forge test

test-with-optimization: build-with-optimization
	forge test

anvil-deploy: test
	forge script script/Deploy.s.sol:DeployScript --rpc-url anvil --broadcast -v \
      --private-key ${ANVIL_OWNER_PRIVATE_KEY}

sepolia-deploy: test-with-optimization
	forge script script/Deploy.s.sol:DeployScript --rpc-url sepolia --broadcast -vv --verify \
      --private-key ${SOLIDITY_STUDENT_PRIVATE_KEY}

anvil-create-users: build
	forge script script/ScenarioCreateUsers.s.sol:ScenarioCreateUsers --rpc-url anvil --broadcast -v \
      --private-key ${ANVIL_OWNER_PRIVATE_KEY} \
      --sig "run(address,uint256,uint256,uint256)" \
      ${ANVIL_REGISTER_PROXY_ADDRESS} \
      ${ANVIL_OWNER_PRIVATE_KEY} \
      ${ANVIL_USER1_PRIVATE_KEY} \
      ${ANVIL_USER2_PRIVATE_KEY}

sepolia-create-users: build
	forge script script/ScenarioCreateUsers.s.sol:ScenarioCreateUsers --rpc-url sepolia --broadcast -v \
      --private-key ${ANVIL_OWNER_PRIVATE_KEY} \
      --sig "run(address,uint256,uint256,uint256)" \
      ${SEPOLIA_REGISTER_PROXY_ADDRESS} \
      ${SOLIDITY_STUDENT_PRIVATE_KEY} \
      ${SOLIDITY_STUDENT_2_PRIVATE_KEY} \
      ${SOLIDITY_STUDENT_3_PRIVATE_KEY}

anvil-commit: build
	forge script script/ScenarioUserCommit.s.sol:ScenarioUserCommit --rpc-url anvil --broadcast -v \
      --private-key ${ANVIL_OWNER_PRIVATE_KEY} \
      --sig "run(address,uint256)" \
      ${ANVIL_REGISTER_PROXY_ADDRESS} \
      ${ANVIL_OWNER_PRIVATE_KEY}

sepolia-commit: build
	forge script script/ScenarioUserCommit.s.sol:ScenarioUserCommit --rpc-url sepolia --broadcast -v \
      --private-key ${ANVIL_OWNER_PRIVATE_KEY} \
      --sig "run(address,uint256)" \
      ${SEPOLIA_REGISTER_PROXY_ADDRESS} \
      ${SOLIDITY_STUDENT_PRIVATE_KEY}
