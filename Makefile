# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

deploy-testnet:; forge script script/DevDeploy.s.sol:Deploy --fork-url $(FORK_RPC_URL) --private-key $(TEST_PRIVATE_KEY) --broadcast --slow

trace:; forge test -vv