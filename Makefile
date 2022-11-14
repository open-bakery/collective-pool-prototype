# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

deploy-testnet:; forge script script/DevDeploy.s.sol:Deploy --fork-url $(FORK_RPC_URL) --private-key $(TEST_PRIVATE_KEY) --broadcast --slow

trace:; forge test -vv

testUnit:; forge test -vvv --mc UnitTest* --fork-url $(FORK_RPC_URL)

testLocal:; forge test -vvv --match-test testAnvil*

testRatio:; forge test -vvv --mt testDepositRatioCalculator* --fork-url $(FORK_RPC_URL)

testPositionManager:; forge test -vvv --mc RangePoolPositionManager* --fork-url $(FORK_RPC_URL)

testMain:; forge test -vvv --mt testMainnet* --fork-url $(FORK_RPC_URL)
# testMain:; forge test -vvv --mt testMainnet* --fork-url $(FORK_RPC_URL) --gas-report

testArb:; forge test -vvv --mt testArbitrum*  --fork-url $(ARBITRUM_RPC_ALCHEMY)

testLogs:; forge test -vvv --mt testFullLogs* --fork-url $(FORK_RPC_URL)

testGas:; forge test -vv --mc GasTest --gas-report --fork-url $(ARBITRUM_RPC_ALCHEMY)
