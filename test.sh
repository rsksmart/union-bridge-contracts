#!/bin/sh
bash format.sh
echo "================ CLEAN BUILD FOR OZ ================"
forge clean && forge build
echo "================ RUN TESTS ================"
forge test -vvv