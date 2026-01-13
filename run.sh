#!/bin/sh
set -eux
# simulate deploy against rsk testnet
bash shell/script/deploy/simulate-deploy.sh
# gas report (Is also runs tests)
bash shell/gas-report.sh
# packet creation flow is running in the peg flow
bash shell/script/integration-test/local-peg-full-flow.sh
# user reimbursement flow
bash shell/script/integration-test/user-reimbursement-flow.sh
# reject pegin flow
bash shell/script/integration-test/reject-pegin-flow.sh
# run slither
bash shell/slither.sh