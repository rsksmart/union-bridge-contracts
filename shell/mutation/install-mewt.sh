#!/usr/bin/env bash
#
# Install the reviewed mewt release after verifying the installer checksum.
#
# Usage:
#   shell/mutation/install-mewt.sh
#   shell/mutation/install-mewt.sh --version

set -euo pipefail

MEWT_VERSION="v4.0.0"
INSTALLER_SHA256="ad053c500dcdbba3713d3552ed4b9b888a2fed3991b1186186c262b46d171bfb"
INSTALLER_URL="https://github.com/trailofbits/mewt/releases/download/${MEWT_VERSION}/mewt-installer.sh"

if [ "${1:-}" = "--version" ]; then
    printf '%s\n' "$MEWT_VERSION"
    exit 0
fi

installer="$(mktemp)"
trap 'rm -f "$installer"' EXIT

curl --proto '=https' --tlsv1.2 -LsSf "$INSTALLER_URL" -o "$installer"

if command -v sha256sum >/dev/null; then
    actual_sha256="$(sha256sum "$installer" | awk '{print $1}')"
elif command -v shasum >/dev/null; then
    actual_sha256="$(shasum -a 256 "$installer" | awk '{print $1}')"
else
    echo "error: sha256sum or shasum is required to verify the mewt installer." >&2
    exit 1
fi

if [ "$actual_sha256" != "$INSTALLER_SHA256" ]; then
    echo "error: mewt installer checksum mismatch." >&2
    echo "expected: $INSTALLER_SHA256" >&2
    echo "actual:   $actual_sha256" >&2
    exit 1
fi

sh "$installer"
