#!/bin/sh
set -eux

bash test.sh
bash gas-snapshot.sh
sudo docker-compose up
