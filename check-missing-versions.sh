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

check_tag_with_retry() {
  local version="$1"
  local max_retries=10
  local attempt=0

  while [ $attempt -lt $max_retries ]; do
    local headers_file
    headers_file=$(mktemp)
    local http_code
    http_code=$(curl -w "%{http_code}" -D "$headers_file" -o /dev/null -sSL \
      "https://hub.docker.com/v2/repositories/chorrell/node-minimal/tags/${version}")

    if [[ "$http_code" == "200" ]]; then
      rm -f "$headers_file"
      return 1
    elif [[ "$http_code" == "429" ]]; then
      local retry_after
      retry_after=$(grep -i "^retry-after:" "$headers_file" | awk '{print $2}' | tr -d '\r')
      rm -f "$headers_file"

      attempt=$((attempt + 1))
      if [ $attempt -ge $max_retries ]; then
        echo "Error: Docker Hub rate limit exceeded after $max_retries retries for version $version" >&2
        exit 1
      fi

      local jitter
      jitter=$((RANDOM % 11))
      local total_wait=$((retry_after + jitter))
      echo "Rate limited (429) on version $version. Waiting ${total_wait}s (retry-after: ${retry_after}s + jitter: ${jitter}s). Attempt $attempt/$max_retries" >&2
      sleep "$total_wait"
    else
      rm -f "$headers_file"
      return 0
    fi
  done
}

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
      check_tag_with_retry "$PRUNED_VERSION" && echo "$PRUNED_VERSION"
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
