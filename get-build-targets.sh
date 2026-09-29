#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

usage() {
  cat << USAGE
Usage: $0 [-n <VERSION>] [-a]
    -n <VERSION> Resolve the tags for a specific Node.js version (e.g. 20.10.0)
                 instead of auto-detecting the Current and supported LTS releases
    -a           Include targets that are already published to Docker Hub
    -h help

Prints a JSON array of build targets, each with the Node.js version, its major
version, and the image tags it should be published under.

Example:
    $0
    $0 -n 24.21.0
USAGE
  exit 1
}

# The Node.js release index and release schedule (for end-of-life dates).
# Overridable (e.g. with file:// URLs) for tests, along with today's date.
NODE_INDEX_URL="${NODE_INDEX_URL:-https://nodejs.org/dist/index.json}"
NODE_SCHEDULE_URL="${NODE_SCHEDULE_URL:-https://raw.githubusercontent.com/nodejs/Release/main/schedule.json}"
TODAY="${TODAY:-$(date -u +%Y-%m-%d)}"

# Don't build these versions: the static builds are broken.
# These versions fail to compile as static binaries due to compatibility issues
# in Node.js source code. They are treated as if they were never released, so
# the newest non-skipped release of a line is built and tagged instead.
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

VERSION=""
INCLUDE_PUBLISHED="false"

while getopts n:ah? options; do
  case ${options} in
    n)
      VERSION=${OPTARG}
      ;;
    a)
      INCLUDE_PUBLISHED="true"
      ;;
    h)
      usage
      ;;
    \?)
      usage
      ;;
  esac
done

if [[ -n "$VERSION" ]] && ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: Invalid version format '$VERSION'. Expected format: X.Y.Z (e.g., 20.10.0)" >&2
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
SKIP_VERSIONS_JSON=$(echo "$SKIP_VERSIONS" | jq -R . | jq -s .)

# Resolve the build targets and their tags from the Node.js release index.
#
# Releases are sorted newest first by semantic version (not release date, so a
# maintenance patch published after a Current release never counts as newer).
# From that list:
#   latest   - the highest version overall
#   Current  - the highest version, but only while its line is not yet LTS.
#              Between a major entering LTS and the next major shipping there
#              is no Current release, and the `current` tag is left untouched.
#   LTS      - the highest version of each LTS line (codename) whose major
#              has not reached end-of-life in the release schedule. This covers
#              both the Active LTS and Maintenance LTS lines.
#
# Tags for a release:
#   <version>  always
#   <major>    if it is the newest release of its major
#   <codename> if it is the newest release of its LTS line (e.g. krypton)
#   lts        if it is the newest Active LTS release
#   current    if it is the Current release
#   latest     if it is the highest version overall
# shellcheck disable=SC2016 # $vars below are jq variables, not shell
SCHEDULE=$(curl -fsSL --compressed "$NODE_SCHEDULE_URL")
TARGETS=$(curl -fsSL --compressed "$NODE_INDEX_URL" |
  jq -c --argjson skip "$SKIP_VERSIONS_JSON" --arg version "$VERSION" \
    --argjson schedule "$SCHEDULE" --arg today "$TODAY" '
    def major: split(".")[0];
    # A major without a schedule entry is assumed to be supported.
    def supported: ($schedule["v" + (.version | major)].end // "9999-12-31") > $today;

    [.[] | {version: (.version | ltrimstr("v")), lts}
      | select(.version | IN($skip[]) | not)]
    | sort_by(.version | split(".") | map(tonumber)) | reverse
    | . as $all
    | .[0] as $latest
    | (first($all[] | select(.lts != false)) // null) as $active_lts

    | def tags:
        . as $r
        | [$r.version]
        + (if first($all[] | select((.version | major) == ($r.version | major))).version == $r.version
           then [$r.version | major] else [] end)
        + (if $r.lts != false and first($all[] | select(.lts == $r.lts)).version == $r.version
           then [$r.lts | ascii_downcase] else [] end)
        + (if $r.version == $active_lts.version then ["lts"] else [] end)
        + (if $r.version == $latest.version and $r.lts == false then ["current"] else [] end)
        + (if $r.version == $latest.version then ["latest"] else [] end);

      if $version != "" then
        [$all[] | select(.version == $version)]
      else
        [$latest]
        + [$all | map(select(.lts != false)) | group_by(.lts)[]
            | max_by(.version | split(".") | map(tonumber)) | select(supported)]
        | unique_by(.version)
      end
      | map({version, major: (.version | major), tags: tags})
  ')

if [[ -n "$VERSION" ]] && [[ "$TARGETS" == "[]" ]]; then
  echo "Error: Node.js version '$VERSION' was not found in the release index or is in SKIP_VERSIONS" >&2
  exit 1
fi

# Drop targets that are already published, unless a specific version was
# requested (a manual rebuild) or -a was given.
if [[ -z "$VERSION" ]] && [[ "$INCLUDE_PUBLISHED" == "false" ]]; then
  MISSING=()
  while IFS= read -r target_version; do
    if check_tag_with_retry "$target_version"; then
      MISSING+=("$target_version")
    fi
  done < <(jq -r '.[].version' <<< "$TARGETS")

  MISSING_JSON=$(printf '%s\n' "${MISSING[@]+"${MISSING[@]}"}" | jq -R 'select(. != "")' | jq -s .)
  TARGETS=$(jq -c --argjson missing "$MISSING_JSON" 'map(select(.version | IN($missing[])))' <<< "$TARGETS")
fi

echo "$TARGETS"
