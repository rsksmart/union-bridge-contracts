#!/bin/bash
set -e
echo "================ CLEAN BUILD FOR OZ ================"
# openzeppelin-foundry-upgrades requires a clean build
forge clean && forge build