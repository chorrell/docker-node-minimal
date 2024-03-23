#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

NODE_VERSIONS=$(curl -fsSLo- --compressed https://nodejs.org/dist/index.json | jq '.[].version' | tr -d '"' | tr -d 'v' | head -10)

#MAJOR_VERSION=$(echo "${NODE_VERSION}" | cut -d'.' -f 1)

# Check for specific tag based on NODE_VERSION

MISSING_VERSIONS=
for NODE_VERSION in $NODE_VERSIONS; do
  if ! docker manifest inspect chorrell/node-minimal:"${NODE_VERSION}" > /dev/null 2>&1;
  then
    MISSING_VERSIONS+=( "${NODE_VERSION}" )
  fi
done

echo "${MISSING_VERSIONS[@]}" | sort
