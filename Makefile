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
