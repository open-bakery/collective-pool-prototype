#!/bin/bash

BASEDIR="$PWD/$(dirname "$0")"
echo "getting env vars from $BASEDIR/.env"
. "$BASEDIR/.env"

echo "deploying locally with key: $DEPLOYER_PRIVATE_KEY"
rm "$BASEDIR/$DEPLOY_OUT"

PARAMS="--rpc-url http://127.0.0.1:8545 --private-key $DEPLOYER_PRIVATE_KEY";
forge script script/DeployUniswap.s.sol:DeployUniswap $PARAMS --slow --broadcast
sleep 1
forge script script/DeployRangePools.s.sol:DeployRangePools $PARAMS --slow --broadcast

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

FACTORY_ADDRESS=`jq .uniFactory -r dist/local.json`
ADDR=$FACTORY_ADDRESS yq -i '.dataSources[0].source.address = strenv(ADDR)' ../uniswap-v3-subgraph/subgraph.yaml
ADDR=`jq .positionManager -r dist/local.json` yq -i '.dataSources[1].source.address = strenv(ADDR)' ../uniswap-v3-subgraph/subgraph.yaml
echo "export const FACTORY_ADDRESS = '$FACTORY_ADDRESS'" > ../uniswap-v3-subgraph/src/utils/factoryAddress.ts;
