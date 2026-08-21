include .env
export
.PHONY: build test coverage snapshot gas deploy-local deploy-test

build:
	forge build

test:
	forge test -vv

coverage:
	forge coverage

snapshot:
	forge snapshot

build:
	forge build

test:
	forge test -vv

clean:
	forge clean

coverage:
	forge coverage

snapshot:
	forge snapshot

gas:
	forge test --gas-report

deploy-local-v1:
	forge script script/DeployVaultStream.s.sol --rpc-url $(RPC) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vvvv

deploy-local-v2:
	forge script script/UpgradeVaultStream.s.sol --rpc-url $(RPC) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vvvv

deploy-test-v1:
	forge script script/DeployVaultStream.s.sol --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
