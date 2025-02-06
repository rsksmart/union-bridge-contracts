#!/bin/sh
set -eux

bash test.sh
bash gas-snapshot.sh
bash simulate-deploy.sh
bash slither.sh
