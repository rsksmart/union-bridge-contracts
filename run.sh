#!/bin/sh
set -eux
bash shell/script/deploy/simulate-deploy.sh
bash shell/format.sh
# gas report also runs test
bash shell/gas-report.sh
# FIXME: uncomment next line after we add the scripts to register members and create committee
# bash shell/script/local-peg-full-flow.sh      
bash shell/slither.sh