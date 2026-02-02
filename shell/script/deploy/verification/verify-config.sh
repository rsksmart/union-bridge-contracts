#!/bin/bash
# Configuration and setup for contract verification scripts

# Get the directory where this script is located
CURRENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT="$(cd "$CURRENT_PATH/../../../../" && pwd)"

# Compiler settings from foundry.toml
# Parse foundry.toml to extract compiler settings
FOUNDRY_TOML="$PROJECT_ROOT/foundry.toml"

if [[ -f "$FOUNDRY_TOML" ]]; then
    # Use awk to parse TOML (handles [profile.default] section)
    # Extract values, only set if not already set
    # Patterns allow for leading whitespace (indentation) in foundry.toml
    : "${COMPILER_VERSION:=$(awk -F'=' '/^[[:space:]]*solc_version/ {gsub(/[" ]/, "", $2); print $2}' "$FOUNDRY_TOML")}"
    : "${OPTIMIZER_ENABLED:=$(awk -F'=' '/^[[:space:]]*optimizer[^_]/ {gsub(/[ #]/, "", $2); print tolower($2)}' "$FOUNDRY_TOML")}"
    : "${OPTIMIZER_RUNS:=$(awk -F'=' '/^[[:space:]]*optimizer_runs/ {gsub(/[ #]/, "", $2); print $2}' "$FOUNDRY_TOML")}"
    : "${EVM_VERSION:=$(awk -F'=' '/^[[:space:]]*evm_version/ {gsub(/[" ]/, "", $2); print $2}' "$FOUNDRY_TOML")}"
fi
