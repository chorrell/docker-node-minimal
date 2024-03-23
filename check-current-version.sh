#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

NODE_VERSION=$(curl -fsSLo- --compressed https://nodejs.org/dist/index.json | jq '.[1].version' | tr -d '"' | tr -d 'v')
MAJOR_VERSION=$(echo "${NODE_VERSION}" | cut -d'.' -f 1)

# Check for specific tag based on NODE_VERSION
if ! docker manifest inspect chorrell/node-minimal:"${NODE_VERSION}" > /dev/null 2>&1;
then
  echo "NODE_VERSION=$NODE_VERSION"
  echo "MAJOR_VERSION=$MAJOR_VERSION"
fi
