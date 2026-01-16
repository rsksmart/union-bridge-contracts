#!/bin/bash
set -e
echo "================ RUN TESTS ================"
# Exclude CommitteeMemberIterationGas.t.sol from tests, no need these utility gas consumption tests all the time.
# To run gas consumption utility tests, use the gas-report.sh script.
forge test -vvv --no-match-path "test/CommitteeMemberIterationGas.t.sol"
