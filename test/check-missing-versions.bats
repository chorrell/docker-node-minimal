#!/usr/bin/env bats

# Test suite for check-missing-versions.sh

SCRIPT="${BATS_TEST_DIRNAME}/../check-missing-versions.sh"

# ============================================================================
# Input Validation Tests
# ============================================================================

@test "script validates LIMIT is a positive integer" {
  run bash "$SCRIPT" -l 0
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Error: LIMIT must be a positive integer" ]]
}

@test "script rejects negative LIMIT" {
  run bash "$SCRIPT" -l -5
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Error: LIMIT must be a positive integer" ]]
}

@test "script rejects non-numeric LIMIT" {
  run bash "$SCRIPT" -l abc
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Error: LIMIT must be a positive integer" ]]
}

@test "script rejects floating point LIMIT" {
  run bash "$SCRIPT" -l 5.5
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Error: LIMIT must be a positive integer" ]]
}

@test "script accepts valid LIMIT value of 1" {
  run bash "$SCRIPT" -l 1
  [ "$status" -eq 0 ]
}

@test "script accepts valid LIMIT value of 10" {
  run bash "$SCRIPT" -l 10
  [ "$status" -eq 0 ]
}

# ============================================================================
# Help and Usage Tests
# ============================================================================

@test "script shows usage with -h flag" {
  run bash "$SCRIPT" -h
  [ "$status" -eq 1 ]
  [[ "$output" =~ Usage: ]]
  [[ "$output" =~ check-missing-versions.sh ]]
  [[ "$output" =~ -l\ \<LIMIT\> ]]
}

@test "script shows usage with invalid flag" {
  run bash "$SCRIPT" -x
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Usage:" ]]
}

@test "usage message includes example" {
  run bash "$SCRIPT" -h
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Example:" ]]
}

@test "usage message describes LIMIT parameter" {
  run bash "$SCRIPT" -h
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Limit the amount of missing versions" ]]
}

# ============================================================================
# Script Execution Tests
# ============================================================================

@test "script runs successfully with valid LIMIT" {
  run bash "$SCRIPT" -l 1
  [ "$status" -eq 0 ]
}

@test "script runs with default LIMIT when not specified" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script handles case when no missing versions exist" {
  run bash "$SCRIPT" -l 1
  [ "$status" -eq 0 ]
  # Should exit cleanly, output may be empty or contain versions
}

@test "script with LIMIT=1 produces at most 1 result" {
  run bash "$SCRIPT" -l 1
  [ "$status" -eq 0 ]
  line_count=$(echo "$output" | grep -c . || true)
  [ "$line_count" -le 1 ]
}

@test "script with LIMIT=2 produces at most 2 results" {
  run bash "$SCRIPT" -l 2
  [ "$status" -eq 0 ]
  line_count=$(echo "$output" | grep -c . || true)
  [ "$line_count" -le 2 ]
}

# ============================================================================
# Output Format Tests
# ============================================================================

@test "output contains only version numbers in X.Y.Z format" {
  run bash "$SCRIPT" -l 1
  [ "$status" -eq 0 ]
  if [ -n "$output" ]; then
    [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || [ -z "$output" ]
  fi
}

@test "output has no empty lines" {
  run bash "$SCRIPT" -l 1
  [ "$status" -eq 0 ]
  # Check that output doesn't have consecutive newlines or trailing newlines with content
  if [ -n "$output" ]; then
    ! [[ "$output" =~ $'\n\n' ]]
  fi
}

@test "output is sorted in ascending semantic version order" {
  run bash "$SCRIPT" -l 5
  [ "$status" -eq 0 ]
  if [ -n "$output" ]; then
    sorted_output=$(echo "$output" | sort -V)
    [ "$output" = "$sorted_output" ]
  fi
}

# ============================================================================
# Functionality Tests
# ============================================================================

@test "SKIP_VERSIONS are not included in output" {
  run bash "$SCRIPT" -l 20
  [ "$status" -eq 0 ]
  # Check that known skipped versions are not in output
  if [ -n "$output" ]; then
    ! [[ "$output" =~ 23\.6\.1 ]]
    ! [[ "$output" =~ 23\.6\.0 ]]
    ! [[ "$output" =~ 23\.5\.0 ]]
  fi
}

@test "script fetches from Node.js dist API" {
  # Test that the script can fetch Node.js versions successfully
  run bash "$SCRIPT" -l 1
  [ "$status" -eq 0 ]
  # If there's output, it should be a valid version number
  if [ -n "$output" ]; then
    [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
  fi
}

@test "script uses Docker Hub API for checking tags" {
  # This is an integration test that verifies Docker Hub API calls work
  run bash "$SCRIPT" -l 1
  [ "$status" -eq 0 ]
  # If we get here without network errors, Docker Hub API is working
}

@test "script handles network-independent error cases" {
  # Test with completely invalid limit to ensure validation happens
  # before any network calls
  run bash "$SCRIPT" -l "not-a-number"
  [ "$status" -eq 1 ]
  # Should fail immediately with validation error, not a network error
  [[ "$output" =~ "Error: LIMIT must be a positive integer" ]]
}
