#!/usr/bin/env bash
set -euo pipefail

echo "================ UPDATE GAS SNAPSHOT ================"

EXCLUDES=(--no-match-path "test/{CommitteeMemberIterationGas,scripts/*}.t.sol" --no-match-test "GasConsumption")

if [ "${1:-}" = "--check" ]; then
    forge snapshot --check "${EXCLUDES[@]}"
else
    forge snapshot "${EXCLUDES[@]}"
    echo "Updated .gas-snapshot"
fi
