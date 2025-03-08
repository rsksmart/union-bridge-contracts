#!/bin/sh
set -eux
bash shell/script/deploy/simulate-deploy.sh
bash shell/format.sh
bash shell/test.sh
bash shell/gas-snapshot.sh
bash shell/slither.sh