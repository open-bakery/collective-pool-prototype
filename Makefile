# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

deploy-testnet:; forge script script/Contract.s.sol:ContractScript --rpc-url $(TEST_RPC_URL) --private-key $(TEST_PRIVATE_KEY) --broadcast --slow

trace:; forge test -vv

testLocal:; forge test -vvv --match-test testAnvil*

testMain:; forge test -vvv --match-test testMainnet* --fork-url $(FORK_RPC_URL)

testArb:; forge test -vvv --mt testArbitrum*  --fork-url $(ARBITRUM_RPC_ALCHEMY)

testPool:; forge test -vv --mc PoolTest --fork-url $(ARBITRUM_RPC_ALCHEMY)

testGas:; forge test --vv --mc GasTest --gas-report --fork-url $(ARBITRUM_RPC_ALCHEMY)
