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

# Don't build these versions: the static builds are broken.
# These versions fail to compile as static binaries due to compatibility issues
# in Node.js source code. They are filtered out from the pipeline using jq's
# index() function in the filtering section below.
SKIP_VERSIONS=$(
  cat << 'EOF'
23.6.1
23.6.0
23.5.0
23.4.0
23.3.0
22.13.1
22.13.0
EOF
)

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

# Check if a Docker tag exists on Docker Hub using the Docker Hub API.
# Handles HTTP 429 (rate limit) responses by parsing the Retry-After header
# and retrying with exponential backoff + jitter to avoid thundering herd.
# Reference: https://docs.docker.com/reference/api/hub/latest/#tag/rate-limiting
#
# Parameters:
#   $1 - version: The Node.js version tag to check (e.g., "20.10.0")
#
# Return values:
#   0 - Tag does NOT exist on Docker Hub (version is missing)
#   1 - Tag exists on Docker Hub (version already built)
#   exit 1 - Fatal error: rate limit exceeded after all retries
check_tag_with_retry() {
  local version="$1"
  local max_retries=10
  local attempt=0

  while [ $attempt -lt $max_retries ]; do
    local response
    # Capture headers (via -D -) and HTTP code (via -w) in single variable
    response=$(curl -w "%{http_code}" -D - -o /dev/null -sSL \
      "https://hub.docker.com/v2/repositories/chorrell/node-minimal/tags/${version}")

    local http_code="${response##*$'\n'}" # Extract last line (HTTP code)
    local headers="${response%$'\n'*}"    # Extract all but last line (headers)

    if [[ "$http_code" == "200" ]]; then
      # Tag found: version already exists on Docker Hub
      return 1
    elif [[ "$http_code" == "429" ]]; then
      # Rate limit hit: Docker Hub returned 429 Too Many Requests
      # Extract Retry-After header which specifies seconds to wait before retry
      local retry_after
      retry_after=$(echo "$headers" | grep -i "^retry-after:" | awk '{print $2}' | tr -d '\r')

      attempt=$((attempt + 1))
      if [ $attempt -ge $max_retries ]; then
        echo "Error: Docker Hub rate limit exceeded after $max_retries retries for version $version" >&2
        exit 1
      fi

      # Add random jitter (0-10s) to retry-after to prevent thundering herd
      # when multiple parallel requests hit rate limit simultaneously
      local jitter
      jitter=$((RANDOM % 11))
      local total_wait=$((retry_after + jitter))
      echo "Rate limited (429) on version $version. Waiting ${total_wait}s (retry-after: ${retry_after}s + jitter: ${jitter}s). Attempt $attempt/$max_retries" >&2
      sleep "$total_wait"
    else
      # Any other response code (404, 500, etc.): tag does not exist
      return 0
    fi
  done
}

# Convert SKIP_VERSIONS to JSON array format for use with jq.
# SKIP_VERSIONS contains newline-separated version strings.
# jq -R reads each line as a raw string, jq -s collects all into a JSON array.
# Result is passed to jq filter via --argjson flag.
SKIP_VERSIONS_JSON=$(echo "$SKIP_VERSIONS" | jq -R . | jq -s .)

# Fetch all Node.js versions from official API, filter SKIP_VERSIONS, and limit.
# Pipeline breaks down as follows:
#   curl ... index.json              - Fetch Node.js release metadata JSON
#   .[].version                      - Extract version field from each release object
#   ltrimstr("v")                    - Remove "v" prefix (e.g., "v20.10.0" → "20.10.0")
#   map(select(...))                 - Filter array keeping only non-skipped versions
#     . as $v                        - Bind current version to variable $v
#     $skip | index($v)              - Check if $v is in SKIP_VERSIONS array
#                                      Returns index (0+) if found, null if not
#     | not                          - Invert: keep version only if NOT in skip list
#   limit($limit; ..[])              - Limit to first N versions using jq (avoids broken pipe)
# Note: Using jq's limit() instead of head to avoid broken pipe error when limiting output
PRUNED_VERSIONS=()
while IFS= read -r version; do
  [[ -n "$version" ]] && PRUNED_VERSIONS+=("$version")
done < <(curl -fsSLo- --compressed https://nodejs.org/dist/index.json |
  jq -r --argjson skip "$SKIP_VERSIONS_JSON" --arg limit "$LIMIT" \
    '[.[].version | ltrimstr("v")] | map(select(. as $v | $skip | index($v) | not)) | limit($limit | tonumber; .[])')

# Check which versions from PRUNED_VERSIONS are missing from Docker Hub.
# Run check_tag_with_retry in parallel (one background job per version) for efficiency.
# Only echo versions where check_tag_with_retry returns 0 (tag does not exist).
# wait blocks until all background jobs complete before continuing.
MISSING_VERSIONS_OUTPUT=$(
  for PRUNED_VERSION in "${PRUNED_VERSIONS[@]}"; do
    (
      check_tag_with_retry "$PRUNED_VERSION" && echo "$PRUNED_VERSION"
    ) &
  done
  wait
)

# Convert output string to array, filtering out empty lines
MISSING_VERSIONS=()
while IFS= read -r version; do
  [[ -n "$version" ]] && MISSING_VERSIONS+=("$version")
done <<< "$MISSING_VERSIONS_OUTPUT"

# Sort missing versions using semantic versioning order (sort -V) before output.
# This ensures CI/CD picks the oldest missing version first when building.
if [ ${#MISSING_VERSIONS[@]} -gt 0 ]; then
  printf '%s\n' "${MISSING_VERSIONS[@]}" | sort -V
fi
