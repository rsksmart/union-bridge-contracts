#!/bin/sh
set -eux

bash simulate-deploy.sh
bash format.sh
forge test -vvv
bash gas-snapshot.sh
bash slither.sh
