#!/bin/sh
set -eux
bash shell/format.sh
bash shell/clean-build.sh
bash shell/test.sh