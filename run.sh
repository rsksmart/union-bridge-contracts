#!/bin/sh
set -eux
# set IS_TEST to true for the integration test
export IS_TEST=true
echo "================ IS TEST: $IS_TEST ================"
# simulate deploy against rsk testnet
bash shell/script/deploy/simulate-deploy.sh
# gas report (It also runs tests)
bash shell/gas-report.sh
# user take flow
bash shell/script/integration-test/user-take-flow.sh
# operator take flow
bash shell/script/integration-test/operator-take-flow.sh
# operator won flow
bash shell/script/integration-test/operator-won-flow.sh
# reject pegin flow
bash shell/script/integration-test/reject-pegin-flow.sh
# user reimbursement flow
bash shell/script/integration-test/user-reimbursement-flow.sh
# run slither
bash shell/slither.sh