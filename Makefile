# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

deploy-testnet:; forge script script/Contract.s.sol:ContractScript --rpc-url $(TEST_RPC_URL) --private-key $(TEST_PRIVATE_KEY) --broadcast --slow

trace:; forge test -vv

unitest:; forge test -vvv --match-test testUni* --fork-url $(FORK_RPC_URL)
