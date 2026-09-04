#!/usr/bin/env bash
#
# Print the comma-separated Solidity mutation slugs that mewt currently
# classifies as high severity. Used by CI when a campaign is too large for
# the job timeout, so we do not hardcode a slug like ER.
#
# Requires mewt and jq on PATH. Usage:
#   shell/mutation/high-severity-mutations.sh

set -euo pipefail

if ! command -v mewt >/dev/null; then
    echo "error: mewt not found on PATH. Run 'make mutate-install'." >&2
    exit 1
fi

if ! command -v jq >/dev/null; then
    echo "error: jq is required to parse mewt mutation JSON." >&2
    exit 1
fi

slugs="$(
    mewt print mutations --language solidity --format json | jq -r '
        [(.mutations // [])[]
            | select((.severity | ascii_downcase) == "high")
            | .slug]
        | unique
        | join(",")
    '
)"

if [ -z "$slugs" ] || [ "$slugs" = "null" ]; then
    echo "error: mewt reported no high-severity Solidity mutations." >&2
    exit 1
fi

printf '%s\n' "$slugs"
