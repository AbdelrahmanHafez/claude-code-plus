# Common test helper functions

# Create a fresh temp directory for each test
setup_test_dir() {
  TEST_DIR=$(mktemp -d)
  export TEST_DIR
}

# Clean up temp directory after each test
teardown_test_dir() {
  if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
    rm -rf "$TEST_DIR"
  fi
}

# Get the project root directory
get_project_root() {
  cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd
}

# Run the installer with test directory
run_install() {
  local project_root
  project_root=$(get_project_root)
  CLAUDE_DIR_OVERRIDE="$TEST_DIR" run "$project_root/install.sh" "$@"
}

# Run the installer and assert success
run_install_ok() {
  run_install "$@"
  if [[ "$status" -ne 0 ]]; then
    echo "Command failed with status $status"
    echo "Output: $output"
    return 1
  fi
}

# Assert file exists
assert_file_exists() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "Expected file to exist: $file"
    return 1
  fi
}

# Assert directory exists
assert_dir_exists() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    echo "Expected directory to exist: $dir"
    return 1
  fi
}

# Assert file is executable
assert_executable() {
  local file="$1"
  if [[ ! -x "$file" ]]; then
    echo "Expected file to be executable: $file"
    return 1
  fi
}

# Assert JSON value equals expected
assert_json_value() {
  local file="$1"
  local path="$2"
  local expected="$3"
  local actual

  actual=$(jq -r "$path" "$file")
  if [[ "$actual" != "$expected" ]]; then
    echo "JSON assertion failed at $path"
    echo "Expected: $expected"
    echo "Actual: $actual"
    return 1
  fi
}

# Assert JSON array contains value
assert_json_contains() {
  local file="$1"
  local array_path="$2"
  local value="$3"

  if ! jq -e "$array_path | index(\"$value\") != null" "$file" > /dev/null 2>&1; then
    echo "JSON array at $array_path does not contain: $value"
    return 1
  fi
}

# Assert output contains string
assert_output_contains() {
  local expected="$1"
  if [[ "$output" != *"$expected"* ]]; then
    echo "Expected output to contain: $expected"
    echo "Actual output: $output"
    return 1
  fi
}
