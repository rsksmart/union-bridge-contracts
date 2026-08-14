#!/usr/bin/env bash
#
# Fail when the mutation allowlist in mewt.toml has drifted from the contracts
# on disk: an active contract with no [[per_target]] mapping would silently lose
# mutation coverage, and a mapping pointing at a missing file is dead config.
#
# Usage:
#   shell/mutation/check-scope.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

exec python3 shell/mutation/scope.py check
