#!/bin/bash
set -e
echo "================ SHOW GAS REPORT ================"
forge test --match-test "test_.*GasConsumptionCheck|test_GasConsumption_"
