#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

LATEST_NODE_VERSION=$(curl -fsSLo- --compressed https://nodejs.org/dist/index.json | jq '.[1].version')

# Check for specific tag based on LATEST_NODE_VERSION
if ! docker manifest inspect chorrell/node-minimal:"${LATEST_NODE_VERSION#v}" > /dev/null 2>&1;
then
  echo "${LATEST_NODE_VERSION#v}"
  else
  echo "BUILT"
fi
