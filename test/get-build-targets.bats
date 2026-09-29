#!/usr/bin/env bats

# Test suite for get-build-targets.sh
#
# Tests run against fixture release indexes (via NODE_INDEX_URL) with -a, so
# they don't depend on the live Node.js release index or Docker Hub.

SCRIPT="${BATS_TEST_DIRNAME}/../get-build-targets.sh"
FIXTURES="${BATS_TEST_DIRNAME}/fixtures"

use_index() {
  export NODE_INDEX_URL="file://${FIXTURES}/$1"
}

# Print the space-separated tags for a version from the script's JSON output.
tags_for() {
  jq -r --arg v "$1" '.[] | select(.version == $v) | .tags | join(" ")' <<< "$output"
}

# ============================================================================
# Input Validation Tests
# ============================================================================

@test "script rejects a version that is not X.Y.Z" {
  run bash "$SCRIPT" -n 20.10
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Invalid version format '20.10'"* ]]
}

@test "script rejects a version with a v prefix" {
  run bash "$SCRIPT" -n v20.10.0
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Error: Invalid version format" ]]
}

@test "script rejects a version that is not in the release index" {
  use_index index-current.json
  run bash "$SCRIPT" -n 99.0.0
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Node.js version '99.0.0' was not found"* ]]
}

@test "script rejects a version in SKIP_VERSIONS" {
  use_index index-current.json
  run bash "$SCRIPT" -n 23.6.1
  [ "$status" -eq 1 ]
  [[ "$output" =~ "was not found in the release index or is in SKIP_VERSIONS" ]]
}

# ============================================================================
# Help and Usage Tests
# ============================================================================

@test "script shows usage with -h flag" {
  run bash "$SCRIPT" -h
  [ "$status" -eq 1 ]
  [[ "$output" =~ Usage: ]]
  [[ "$output" =~ get-build-targets.sh ]]
  [[ "$output" =~ -n\ \<VERSION\> ]]
}

@test "script shows usage with invalid flag" {
  run bash "$SCRIPT" -x
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Usage:" ]]
}

# ============================================================================
# Auto-detected Targets
# ============================================================================

@test "builds the Current and Active LTS releases" {
  use_index index-current.json
  run bash "$SCRIPT" -a
  [ "$status" -eq 0 ]
  [ "$(jq -r '[.[].version] | sort | join(" ")' <<< "$output")" = "24.21.0 26.10.0" ]
}

@test "Current release is tagged current and latest" {
  use_index index-current.json
  run bash "$SCRIPT" -a
  [ "$status" -eq 0 ]
  [ "$(tags_for 26.10.0)" = "26.10.0 26 current latest" ]
}

@test "Active LTS release is tagged lts and its codename" {
  use_index index-current.json
  run bash "$SCRIPT" -a
  [ "$status" -eq 0 ]
  [ "$(tags_for 24.21.0)" = "24.21.0 24 krypton lts" ]
}

@test "maintenance LTS and EOL lines are not built" {
  use_index index-current.json
  run bash "$SCRIPT" -a
  [ "$status" -eq 0 ]
  [ -z "$(tags_for 22.23.3)" ]
  [ -z "$(tags_for 25.9.0)" ]
}

@test "latest is chosen by version, not release date" {
  # 22.23.3 was released after 26.10.0 but is not the newest version
  use_index index-current.json
  run bash "$SCRIPT" -a
  [ "$status" -eq 0 ]
  [ "$(jq -r '.[] | select(.tags | index("latest")) | .version' <<< "$output")" = "26.10.0" ]
}

@test "without a Current line, latest moves to the newest LTS and current is not set" {
  # 26 has entered LTS and 27 has not shipped; 25 is non-LTS but not Current
  use_index index-no-current.json
  run bash "$SCRIPT" -a
  [ "$status" -eq 0 ]
  [ "$(jq length <<< "$output")" -eq 1 ]
  [ "$(tags_for 26.11.0)" = "26.11.0 26 lithium lts latest" ]
  [[ ! "$output" =~ \"current\" ]]
}

@test "SKIP_VERSIONS fall back to the newest non-skipped release" {
  use_index index-skipped.json
  run bash "$SCRIPT" -a
  [ "$status" -eq 0 ]
  [ "$(tags_for 23.2.0)" = "23.2.0 23 current latest" ]
  [ "$(tags_for 22.12.0)" = "22.12.0 22 jod lts" ]
}

@test "output is a compact JSON array with version, major, and tags" {
  use_index index-current.json
  run bash "$SCRIPT" -a
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  jq -e 'all(.[]; (.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) and (.major | test("^[0-9]+$")) and (.tags | length > 0))' <<< "$output"
}

# ============================================================================
# Specific Version (-n)
# ============================================================================

@test "-n resolves tags for the requested version" {
  use_index index-current.json
  run bash "$SCRIPT" -n 26.10.0
  [ "$status" -eq 0 ]
  [ "$(jq length <<< "$output")" -eq 1 ]
  [ "$(tags_for 26.10.0)" = "26.10.0 26 current latest" ]
}

@test "-n on an older patch only tags the exact version" {
  use_index index-current.json
  run bash "$SCRIPT" -n 24.20.0
  [ "$status" -eq 0 ]
  [ "$(tags_for 24.20.0)" = "24.20.0" ]
}

@test "-n on the newest maintenance LTS release tags its major and codename" {
  use_index index-current.json
  run bash "$SCRIPT" -n 22.23.3
  [ "$status" -eq 0 ]
  [ "$(tags_for 22.23.3)" = "22.23.3 22 jod" ]
}

# ============================================================================
# Integration Tests (network)
# ============================================================================

@test "script resolves targets from the live release index and Docker Hub" {
  unset NODE_INDEX_URL
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  jq -e 'type == "array"' <<< "$output"
}
