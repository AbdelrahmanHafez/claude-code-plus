#!/usr/bin/env bats
# Tests for edge cases in command extraction
# These test scenarios where commands might be hidden in unusual shell constructs

load hook_test_helper

# =============================================================================
# Array Assignments with Command Substitutions
# =============================================================================

@test "parse: array initialization with command substitution" {
  run_parse_commands 'arr=($(dangerous_cmd))'
  assert_commands "dangerous_cmd"
}

@test "parse: array initialization with multiple command substitutions" {
  run_parse_commands 'arr=($(cmd1) $(cmd2) literal $(cmd3))'
  assert_commands "cmd1" "cmd2" "cmd3"
}

@test "parse: array initialization with pipe inside" {
  run_parse_commands 'arr=($(find /path | grep pattern))'
  assert_commands "find /path" "grep pattern"
}

@test "parse: array element assignment with command substitution" {
  # This already works because it uses .Value not .Array
  run_parse_commands 'arr[0]=$(dangerous_cmd)'
  assert_commands "dangerous_cmd"
}

@test "permission: block array initialization with unpermitted command" {
  run_hook_block 'arr=($(dangerous_cmd))' '["Bash(echo:*)"]'
  assert_blocked
}

@test "permission: allow array initialization when command permitted" {
  run_hook_allow 'arr=($(ls))' '["Bash(ls:*)"]'
  assert_allowed
}

# =============================================================================
# Parameter Expansion with Command Substitutions
# =============================================================================

@test "parse: parameter default value with command substitution" {
  # The outer command shows simplified $var, but nested cmd IS extracted
  run_parse_commands 'echo ${var:-$(default_cmd)}'
  assert_commands "echo \$var" "default_cmd"
}

@test "parse: parameter assign-default with command substitution" {
  run_parse_commands 'echo ${var:=$(assign_cmd)}'
  assert_commands "echo \$var" "assign_cmd"
}

@test "parse: parameter alternate value with command substitution" {
  run_parse_commands 'echo ${var:+$(alt_cmd)}'
  assert_commands "echo \$var" "alt_cmd"
}

@test "parse: parameter error with command substitution" {
  run_parse_commands 'echo ${var:?$(error_cmd)}'
  assert_commands "echo \$var" "error_cmd"
}

@test "parse: parameter suffix removal with command substitution" {
  run_parse_commands 'echo ${var%$(pattern_cmd)}'
  assert_commands "echo \$var" "pattern_cmd"
}

@test "parse: parameter prefix removal with command substitution" {
  run_parse_commands 'echo ${var#$(pattern_cmd)}'
  assert_commands "echo \$var" "pattern_cmd"
}

@test "parse: parameter replacement with command substitutions" {
  run_parse_commands 'echo ${var/$(old_cmd)/$(new_cmd)}'
  assert_commands "echo \$var" "old_cmd" "new_cmd"
}

@test "parse: nested parameter expansion with command" {
  run_parse_commands 'result=${outer:-${inner:-$(nested_cmd)}}'
  assert_commands "nested_cmd"
}

@test "permission: block parameter expansion with unpermitted command" {
  run_hook_block 'echo ${var:-$(dangerous_cmd)}' '["Bash(echo:*)"]'
  assert_blocked
}

@test "permission: allow parameter expansion when all commands permitted" {
  run_hook_allow 'echo ${var:-$(safe_cmd)}' '["Bash(echo:*)", "Bash(safe_cmd:*)"]'
  assert_allowed
}

# =============================================================================
# Associative Array Operations
# =============================================================================

@test "parse: associative array with command substitution in value" {
  # declare is a declaration builtin, not extracted as command (SAFE)
  # Only the command substitution is extracted
  run_parse_commands 'declare -A arr; arr[key]=$(cmd)'
  assert_commands "cmd"
}

# =============================================================================
# Complex Real-World Patterns
# =============================================================================

@test "parse: variable with default from command in loop" {
  run_parse_commands 'for f in ${files:-$(find . -name "*.txt")}; do cat "$f"; done'
  assert_commands 'find . -name "*.txt"' 'cat "$f"'
}

@test "parse: array from find results" {
  run_parse_commands 'files=($(find /path -type f -name "*.sh"))'
  assert_commands 'find /path -type f -name "*.sh"'
}

@test "parse: mapfile with process substitution" {
  run_parse_commands 'mapfile -t lines < <(dangerous_cmd)'
  assert_commands "mapfile -t lines" "dangerous_cmd"
}

@test "parse: readarray with process substitution" {
  run_parse_commands 'readarray -t arr < <(cmd1 | cmd2)'
  assert_commands "readarray -t arr" "cmd1" "cmd2"
}
