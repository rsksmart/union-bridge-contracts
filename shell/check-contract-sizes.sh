#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SAVED_CONTRACT_MAX_RUNTIME_SIZE="${CONTRACT_MAX_RUNTIME_SIZE:-}"

if [ -f .env ]; then
    # shellcheck disable=SC1091
    set -a
    source .env
    set +a
fi

if [ -n "$SAVED_CONTRACT_MAX_RUNTIME_SIZE" ]; then
    CONTRACT_MAX_RUNTIME_SIZE="$SAVED_CONTRACT_MAX_RUNTIME_SIZE"
fi

MAX_RUNTIME_SIZE="${CONTRACT_MAX_RUNTIME_SIZE:-20000}"

if ! [[ "$MAX_RUNTIME_SIZE" =~ ^[0-9]+$ ]] || [ "$MAX_RUNTIME_SIZE" -le 0 ]; then
    echo "::error::CONTRACT_MAX_RUNTIME_SIZE must be a positive integer (got: ${CONTRACT_MAX_RUNTIME_SIZE:-unset})"
    exit 1
fi

echo "================ CONTRACT SIZE CHECK (max ${MAX_RUNTIME_SIZE} B) ================"

PRODUCTION_CONTRACTS=()
while IFS= read -r contract; do
    PRODUCTION_CONTRACTS+=("$contract")
done < <(find src -maxdepth 1 -name '*.sol' -type f -exec basename {} .sol \; | sort)

if [ "${#PRODUCTION_CONTRACTS[@]}" -eq 0 ]; then
    echo "No production contracts found under src/."
    exit 0
fi

SIZES_FILE="$(mktemp)"
trap 'rm -f "$SIZES_FILE"' EXIT

set +e
forge build --sizes >"$SIZES_FILE" 2>&1
BUILD_EXIT=$?
set -e

# forge build --sizes may exit non-zero when test harnesses exceed EIP-170; ignore that here.
if [ "${BUILD_EXIT}" -ne 0 ] && ! grep -qE '^\| .+ \|' "$SIZES_FILE"; then
    echo "::error::forge build --sizes failed and no size table was produced (exit ${BUILD_EXIT})"
    exit 1
fi

OVER_LIMIT=0

for contract in "${PRODUCTION_CONTRACTS[@]}"; do
    # Runtime size is the second column in the sizes table row.
    line="$(grep -E "^\| ${contract} +\|" "$SIZES_FILE" | head -1 || true)"
    if [ -z "$line" ]; then
        # Abstract contracts (e.g. PegManagerBase) are not deployed standalone.
        continue
    fi

    runtime_size="$(echo "$line" | awk -F'|' '{gsub(/[, ]/, "", $3); print $3}')"

    if [ -z "$runtime_size" ] || ! [[ "$runtime_size" =~ ^[0-9]+$ ]]; then
        echo "::warning::Could not parse runtime size for ${contract}"
        continue
    fi

    if [ "$runtime_size" -gt "$MAX_RUNTIME_SIZE" ]; then
        OVER_LIMIT=$((OVER_LIMIT + 1))
        over_by=$((runtime_size - MAX_RUNTIME_SIZE))
        echo "${contract} runtime size is ${runtime_size} B (+${over_by} B over ${MAX_RUNTIME_SIZE} B quality-gate target; EIP-170 limit is 24576 B)"
    fi
done

if [ "$OVER_LIMIT" -eq 0 ]; then
    echo "All production contracts are within the ${MAX_RUNTIME_SIZE} B recommended runtime size."
    exit 0
fi

echo "${OVER_LIMIT} production contract(s) exceed the ${MAX_RUNTIME_SIZE} B recommended runtime size."
exit 1
