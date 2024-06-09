#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

usage() {
  cat << USAGE
Usage: $0 -l <LIMIT>
    -l <LIMIT> Limit the amount of missing versions returned. Defaults to 10
    -h help
Example:
    $0 -l 5
USAGE
  exit 1
}

LIMIT="10"

while getopts l:h? options; do
  case ${options} in
    l)
      LIMIT=${OPTARG}
      ;;
    h)
      usage
      ;;
    \?)
      usage
      ;;
  esac
done

NODE_VERSIONS=$(curl -fsSLo- --compressed https://nodejs.org/dist/index.json | jq '.[].version' | tr -d '"' | tr -d 'v' | head -"${LIMIT}")

# Check for specific tag based on NODE_VERSION

MISSING_VERSIONS=()
for NODE_VERSION in $NODE_VERSIONS; do
  if ! docker manifest inspect chorrell/node-minimal:"${NODE_VERSION}" > /dev/null 2>&1; then
    MISSING_VERSIONS+=("${NODE_VERSION}")
  fi
done

printf '%s\n' "${MISSING_VERSIONS[@]}"
