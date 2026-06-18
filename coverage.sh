#!/bin/sh
set -eu
bash shell/clean-build.sh
# https://getfoundry.sh/forge/reference/forge-coverage.html
# Align test selection with shell/test.sh and shell/gas-snapshot.sh
forge coverage \
    --report lcov \
    --report summary \
    --no-match-coverage "(script|test)" \
    --no-match-test "GasConsumption" \
    --no-match-contract "(CommitteeMemberIterationGas|ForceCloseCommittee|BitVMXCompatibility|DeployImplAndProxy)"

if [ ! -f lcov.info ]; then
    echo "lcov.info was not generated"
    exit 1
fi
