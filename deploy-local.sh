BASEDIR="$PWD/$(dirname "$0")"
echo "getting env vars from $BASEDIR/.env"
. "$BASEDIR/.env"

echo "deploying locally with key: $DEV_PRIVATE_KEY"
rm "$BASEDIR/$DEPLOY_OUT"
RUST_BACKTRACE=full forge script script/DevDeploy.s.sol:Deploy --fork-url http://127.0.0.1:8545 --private-key $DEV_PRIVATE_KEY --broadcast

# extract abis from artifacts. They'll be linked from subgraph and ui projects
ABIS_DIR="$BASEDIR/dist/abis"
mkdir -p $ABIS_DIR

jq .abi "$BASEDIR/out/RangePoolFactory.sol/RangePoolFactory.json" > "$ABIS_DIR/RangePoolFactory.json"
jq .abi "$BASEDIR/out/RangePool.sol/RangePool.json" > "$ABIS_DIR/RangePool.json"
jq .abi "$BASEDIR/out/ERC20.sol/ERC20.json" > "$ABIS_DIR/ERC20.json"