include .env

build:
	forge fmt && forge clean && forge build

optimized-build:
	forge fmt && forge clean && forge cache clean && forge build --optimize --optimizer-runs 100 --via-ir --sizes

test: build
	forge test

anvil-deploy: test
	forge script script/Deploy.s.sol:DeployScript --rpc-url anvil --broadcast -v \
	  --private-key ${ANVIL_OWNER_PRIVATE_KEY}

sepolia-deploy: test
	forge script script/Deploy.s.sol:DeployScript --rpc-url sepolia --broadcast -vv --verify \
	  --optimize --optimizer-runs 100 \
      --private-key ${SOLIDITY_STUDENT_PRIVATE_KEY}

mainnet-deploy: test
	forge script script/Deploy.s.sol:DeployScript --rpc-url mainnet --broadcast -vv --verify \
	  --optimize --optimizer-runs 100 \
      --private-key ${SOLIDITY_STUDENT_PRIVATE_KEY}

full-scenario: build
	cd bash && \
	  ./action-register.sh anvil "${ANVIL_OWNER_PRIVATE_KEY}" owner && \
	  ./action-register.sh anvil "${ANVIL_USER1_PRIVATE_KEY}" user1 && \
	  ./action-register.sh anvil "${ANVIL_USER2_PRIVATE_KEY}" user2 && \
	  ./action-settings.sh anvil "${ANVIL_OWNER_PRIVATE_KEY}" 1 1 && \
	  ./action-commit.sh anvil "${ANVIL_OWNER_PRIVATE_KEY}" "I am president" 0 false "secret0" && \
	  ./action-commit.sh anvil "${ANVIL_USER1_PRIVATE_KEY}" "I hate cats" 1000000000000000000000 true "secret1" && \
	  ./action-guess.sh anvil "${ANVIL_OWNER_PRIVATE_KEY}" 2 3000000000000000000000 false "secret0" && \
	  ./action-guess.sh anvil "${ANVIL_USER2_PRIVATE_KEY}" 2 1000000000000000000000 true "secret2" && \
	  ./action-reveal.sh anvil "${ANVIL_OWNER_PRIVATE_KEY}" 2 "secret0" && \
	  ./action-reveal.sh anvil "${ANVIL_USER1_PRIVATE_KEY}" 2 "secret1" && \
	  ./action-reveal.sh anvil "${ANVIL_USER2_PRIVATE_KEY}" 2 "secret2" && \
	  ./full-report.sh anvil "${ANVIL_OWNER_PRIVATE_KEY}"
