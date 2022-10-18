BASEDIR="$PWD/$(dirname "$0")"
echo "getting env vars from $BASEDIR/.env"
. "$BASEDIR/.env"

echo "deploying locally with key: $DEV_PRIVATE_KEY"
RUST_BACKTRACE=full forge script script/DevDeploy.s.sol:Deploy --fork-url http://127.0.0.1:8545 --private-key $DEV_PRIVATE_KEY --broadcast -vvv
