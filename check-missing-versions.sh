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

# Don't build these versions: the static builds are broken
SKIP_VERSIONS=("23.6.1" "23.6.0" "23.5.0" "23.4.0" "23.3.0" "22.13.1" "22.13.0")

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

if ! [[ "$LIMIT" =~ ^[0-9]+$ ]] || [ "$LIMIT" -lt 1 ]; then
  echo "Error: LIMIT must be a positive integer" >&2
  exit 1
fi

NODE_VERSIONS=$(curl -fsSLo- --compressed https://nodejs.org/dist/index.json | jq '.[].version' | tr -d '"' | tr -d 'v' | head -"${LIMIT}")

PRUNED_VERSIONS=()
for NODE_VERSION in $NODE_VERSIONS; do
  skip=
  for VERSION in "${SKIP_VERSIONS[@]}"; do
    [[ $NODE_VERSION == "$VERSION" ]] && {
      skip=1
      break
    }
  done
  [[ -n $skip ]] || PRUNED_VERSIONS+=("$NODE_VERSION")
done

# Check for specific tag based on PRUNED_VERSION
MISSING_VERSIONS=()
for PRUNED_VERSION in "${PRUNED_VERSIONS[@]}"; do
  if ! docker manifest inspect chorrell/node-minimal:"$PRUNED_VERSION" > /dev/null 2>&1; then
    MISSING_VERSIONS+=("$PRUNED_VERSION")
  fi
done

if [ ${#MISSING_VERSIONS[@]} -gt 0 ]; then
  printf '%s\n' "${MISSING_VERSIONS[@]}"
fi
