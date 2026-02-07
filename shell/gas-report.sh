#!/bin/bash
set -e
echo "================ SHOW GAS REPORT ================"
forge test --gas-report --no-match-test "GasConsumption" --no-match-path "test/scripts/*"
