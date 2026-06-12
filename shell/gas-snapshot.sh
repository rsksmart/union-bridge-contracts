#!/usr/bin/env bash
set -euo pipefail

echo "================ UPDATE GAS SNAPSHOT ================"

# Exclude heavy / environment-sensitive tests (full in-test deploys, gas benchmarks, script tests).
EXCLUDES=(
    --no-match-path "test/{CommitteeMemberIterationGas,scripts/*,BitVMXCompatibility,deploy/*}.t.sol"
    --no-match-test "GasConsumption"
)

if [ "${1:-}" = "--check" ]; then
    forge snapshot --check "${EXCLUDES[@]}"
else
    forge snapshot "${EXCLUDES[@]}"
    echo "Updated .gas-snapshot"
fi
