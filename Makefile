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

deploy-local:
	forge script script/DeployVaultStream.s.sol --rpc-url $(RPC) --private-key $(ANVIL_PRIVATE_KEY) --broadcast -vvvv
