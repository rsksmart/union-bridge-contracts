#!/bin/sh
set -eux

bash simulate-deploy.sh
bash test.sh
bash gas-snapshot.sh
bash slither.sh
