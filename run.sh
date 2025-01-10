#!/bin/sh
bash format.sh
bash test.sh
bash gas-snapshot.sh
docker-compose up