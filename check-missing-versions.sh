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

# Convert SKIP_VERSIONS array to JSON for jq filtering
SKIP_VERSIONS_JSON=$(printf '%s\n' "${SKIP_VERSIONS[@]}" | jq -R . | jq -s .)

# Fetch, filter skip list, remove 'v' prefix, and limit in one pipeline
PRUNED_VERSIONS=()
while IFS= read -r version; do
  [[ -n "$version" ]] && PRUNED_VERSIONS+=("$version")
done < <(curl -fsSLo- --compressed https://nodejs.org/dist/index.json |
  jq -r --argjson skip "$SKIP_VERSIONS_JSON" \
    '[.[].version | ltrimstr("v")] | map(select(. as $v | $skip | index($v) | not)) | .[]' |
  head -"${LIMIT}")

# Check for specific tags in parallel using Docker Hub API
MISSING_VERSIONS_OUTPUT=$(
  for PRUNED_VERSION in "${PRUNED_VERSIONS[@]}"; do
    (
      HTTP_CODE=$(curl -w "%{http_code}" -o /dev/null -sSL \
        "https://hub.docker.com/v2/repositories/chorrell/node-minimal/tags/${PRUNED_VERSION}")
      [[ "$HTTP_CODE" != "200" ]] && echo "$PRUNED_VERSION"
    ) &
  done
  wait
)

# Convert output to array, filtering empty lines
MISSING_VERSIONS=()
while IFS= read -r version; do
  [[ -n "$version" ]] && MISSING_VERSIONS+=("$version")
done <<< "$MISSING_VERSIONS_OUTPUT"

# Sort versions before printing (semantic version sort)
if [ ${#MISSING_VERSIONS[@]} -gt 0 ]; then
  printf '%s\n' "${MISSING_VERSIONS[@]}" | sort -V
fi
