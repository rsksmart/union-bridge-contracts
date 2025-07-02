#!/bin/sh
set -eux
# clean build
bash shell/clean-build.sh
# generate bindings for rust crate
bash shell/generate-bind.sh
# generate docs
bash shell/generate-doc.sh