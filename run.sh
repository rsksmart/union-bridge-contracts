#!/bin/sh
set -eux
# set IS_TEST to true for the integration test
export IS_TEST=true
echo "================ IS TEST: $IS_TEST ================"
# simulate deploy against rsk testnet
bash shell/script/deploy/simulate-deploy.sh
# gas report (It also runs tests)
bash shell/gas-report.sh
# packet creation flow is running in the peg flow
bash shell/script/integration-test/local-peg-full-flow.sh
# user reimbursement flow
bash shell/script/integration-test/user-reimbursement-flow.sh
# reject pegin flow
bash shell/script/integration-test/reject-pegin-flow.sh
# run slither
bash shell/slither.sh