BASEDIR="$PWD/$(dirname "$0")"
echo "getting env vars from $BASEDIR/.env"
. "$BASEDIR/.env"

echo "deploying locally with key: $DEV_PRIVATE_KEY"
rm "$BASEDIR/$DEPLOY_OUT"
RUST_BACKTRACE=full forge script script/DevDeploy.s.sol:Deploy --fork-url http://127.0.0.1:8545 --private-key $DEV_PRIVATE_KEY --broadcast

# extract abis from artifacts. They'll be linked from subgraph and ui projects
ABIS_DIR="$BASEDIR/dist/abis"
mkdir -p $ABIS_DIR

for contract in RangePoolFactory RangePool ERC20 IUniswapV3Pool; do
  jq .abi "$BASEDIR/out/$contract.sol/$contract.json" > "$ABIS_DIR/$contract.json"
done;
