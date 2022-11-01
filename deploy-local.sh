#!/bin/bash

BASEDIR="$PWD/$(dirname "$0")"
echo "getting env vars from $BASEDIR/.env"
. "$BASEDIR/.env"

echo "deploying locally with key: $DEV_PRIVATE_KEY"
rm "$BASEDIR/$DEPLOY_OUT"
RUST_BACKTRACE=full forge script script/DevDeploy.s.sol:Deploy --fork-url http://127.0.0.1:8545 --private-key $DEV_PRIVATE_KEY --broadcast

# extract abis from artifacts. They'll be linked from subgraph and ui projects
DIST_DIR="$BASEDIR/dist"
ABIS_DIR="$DIST_DIR/abis"
mkdir -p $ABIS_DIR

declare -A contracts
contracts[factory]=RangePoolFactory
contracts[lens]=Lens
contracts[pool]=RangePool
contracts[erc20]=ERC20
contracts[uniPool]=IUniswapV3Pool
contracts[positionManager]=NonfungiblePositionManager

indexImport=""
indexExport="export const abis = {
"

for key in "${!contracts[@]}"
do
  contract="${contracts[$key]}"
  echo "$key: $contract"
  jsonAbi=`jq .abi "$BASEDIR/out/$contract.sol/$contract.json"`
  echo "$jsonAbi" > "$ABIS_DIR/$contract.json"
  echo "export default $jsonAbi as const;" > "$ABIS_DIR/$contract.ts"
  indexImport="${indexImport}import $key from './$contract';
"
  indexExport="${indexExport}  ${key},
"
done

indexExport="${indexExport}};
"
echo "$indexImport

$indexExport" > "$ABIS_DIR/index.ts"

echo "export default `cat $DIST_DIR/local.json` as const;" > "$DIST_DIR/local.ts";

SM00T_DIR="$BASEDIR/../sm00th"
cp -r $ABIS_DIR/*.ts $SM00T_DIR/@app/ui/abis
cp $DIST_DIR/local.ts $SM00T_DIR/@app/ui/const
cp $DIST_DIR/local.json $SM00T_DIR/@app/subgraph/contracts
cp -r $ABIS_DIR/*.json $SM00T_DIR/@app/subgraph/contracts/abis

