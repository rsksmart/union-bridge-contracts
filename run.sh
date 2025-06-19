#!/bin/sh
set -eux
bash shell/script/deploy/simulate-deploy.sh
# gas report also runs test
bash shell/gas-report.sh
# packet creation flow is running also in the peg flow maybe it's not needed here
bash shell/script/local-packet-creation-full-flow.sh 
bash shell/script/local-peg-full-flow.sh
bash shell/slither.sh