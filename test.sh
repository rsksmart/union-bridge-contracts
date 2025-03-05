#!/bin/sh
bash script/format.sh
echo "================ CLEAN BUILD FOR OZ ================"
# openzeppelin-foundry-upgrades requires a clean build
forge clean && forge build
echo "================ RUN TESTS ================"
forge test -vvv