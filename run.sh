#!/bin/sh
set -eux
bash shell/script/deploy/simulate-deploy.sh
# gas report also runs test
bash shell/gas-report.sh
# packet creation flow is running in the peg flow
bash shell/script/integration-test/local-peg-full-flow.sh
bash shell/slither.sh