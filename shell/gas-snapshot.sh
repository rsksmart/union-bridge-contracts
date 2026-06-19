#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "================ UPDATE GAS SNAPSHOT ================"

# Exclude heavy / environment-sensitive tests (full in-test deploys, gas benchmarks, script tests).
EXCLUDES=(
    --no-match-contract "(CommitteeMemberIterationGas|BitVMXCompatibility|DeployImplAndProxy|ForceCloseCommittee)"
    --no-match-test "GasConsumption"
)

if [ "${1:-}" = "--check" ]; then
    forge snapshot --check "${EXCLUDES[@]}"
else
    forge snapshot "${EXCLUDES[@]}"
    echo "Updated .gas-snapshot"
fi
