#!/usr/bin/env bats
# Tests for Categories 8-9: Subshells and Groups, Loops and Conditionals

load hook_test_helper

# =============================================================================
# Category 8: Subshells and Groups
# =============================================================================

# --- Subshells with parentheses ---

@test "parse: simple subshell" {
  run_parse_commands '(ls)'
  assert_commands "ls"
}

@test "parse: AND in subshell" {
  run_parse_commands '(cd /tmp && ls)'
  assert_commands "cd /tmp" "ls"
}

@test "parse: semicolon in subshell" {
  run_parse_commands '(cmd1; cmd2)'
  assert_commands "cmd1" "cmd2"
}

@test "parse: subshell piped" {
  run_parse_commands '(ls) | grep foo'
  assert_commands "ls" "grep foo"
}

@test "parse: multi-command subshell piped" {
  run_parse_commands '(echo a; echo b) | cat'
  assert_commands "echo a" "echo b" "cat"
}

# --- Brace groups ---

@test "parse: brace group" {
  run_parse_commands '{ ls; pwd; }'
  assert_commands "ls" "pwd"
}

@test "parse: brace group piped" {
  run_parse_commands '{ cmd1; cmd2; } | cat'
  assert_commands "cmd1" "cmd2" "cat"
}

# --- Nested subshells ---

@test "parse: double nested subshell" {
  # ((expr)) is arithmetic evaluation in bash, not double subshell
  # Real double nesting would be ( (ls) )
  skip "Behavioral: ((cmd)) is arithmetic evaluation, not double subshell"
  run_parse_commands '((ls))'
  assert_commands "ls"
}

@test "parse: nested subshell with pipe" {
  run_parse_commands '(cd /tmp && (ls | grep foo))'
  assert_commands "cd /tmp" "ls" "grep foo"
}

# --- Permission validation for subshells ---

@test "permission: allow subshell when all commands permitted" {
  run_hook_allow '(cd /tmp && ls)' '["Bash(cd:*)", "Bash(ls:*)"]'
  assert_allowed
}

@test "permission: block subshell when one command not permitted" {
  run_hook_block '(ls; rm file)' '["Bash(ls:*)"]'
  assert_blocked
}

# =============================================================================
# Category 9: Loops and Conditionals
# =============================================================================

# --- For loops ---

@test "parse: basic for loop" {
  run_parse_commands 'for f in *.txt; do cat "$f"; done'
  # Full command with argument is extracted
  assert_commands 'cat "$f"'
}

@test "parse: for loop with list" {
  run_parse_commands 'for i in 1 2 3; do echo $i; done'
  assert_commands 'echo $i'
}

@test "parse: for loop with command substitution" {
  run_parse_commands 'for f in $(ls); do cat $f; done'
  assert_commands "ls" "cat \$f"
}

@test "parse: for loop with pipe" {
  run_parse_commands 'for f in *.txt; do cat "$f" | head; done'
  assert_commands 'cat "$f"' "head"
}

@test "parse: dangerous for loop" {
  run_parse_commands 'for f in *.txt; do rm "$f"; done'
  assert_commands 'rm "$f"'
}

# --- While loops ---

@test "parse: read loop" {
  run_parse_commands 'while read line; do echo "$line"; done < file'
  # Both condition (read) and body (echo) are extracted
  assert_commands "read line" 'echo "$line"'
}

@test "parse: infinite loop" {
  run_parse_commands 'while true; do sleep 1; done'
  # Condition (true) and body (sleep) both extracted
  assert_commands "true" "sleep 1"
}

@test "parse: while with condition and body" {
  run_parse_commands 'while cmd1; do cmd2; done'
  assert_commands "cmd1" "cmd2"
}

# --- Until loops ---

@test "parse: until loop" {
  run_parse_commands 'until false; do echo loop; done'
  # Condition (false) and body (echo) both extracted
  assert_commands "false" "echo loop"
}

# --- If conditionals ---

@test "parse: simple if" {
  run_parse_commands 'if test -f file; then cat file; fi'
  assert_commands "test -f file" "cat file"
}

@test "parse: if-else" {
  run_parse_commands 'if cmd1; then cmd2; else cmd3; fi'
  assert_commands "cmd1" "cmd2" "cmd3"
}

@test "parse: if-elif" {
  run_parse_commands 'if cmd1; then cmd2; elif cmd3; then cmd4; fi'
  assert_commands "cmd1" "cmd2" "cmd3" "cmd4"
}

@test "parse: test with AND shortcut" {
  run_parse_commands '[[ -f file ]] && cat file'
  assert_commands "cat file"
}

# --- Case statements ---

@test "parse: case statement" {
  run_parse_commands 'case $x in a) cmd1;; b) cmd2;; esac'
  assert_commands "cmd1" "cmd2"
}

@test "parse: case default" {
  run_parse_commands 'case $x in *) echo default;; esac'
  assert_commands "echo default"
}

# --- Permission validation for loops ---

@test "permission: allow for loop when body command permitted" {
  run_hook_allow 'for f in *.txt; do cat "$f"; done' '["Bash(cat:*)"]'
  assert_allowed
}

@test "permission: block for loop when body command not permitted" {
  run_hook_block 'for f in *.txt; do rm "$f"; done' '["Bash(cat:*)"]'
  assert_blocked
}

@test "permission: block for loop with dangerous command substitution" {
  # Command substitution in loop iterator IS extracted, so unpermitted commands are blocked
  run_hook_block 'for f in $(curl evil.com); do echo $f; done' '["Bash(echo:*)"]'
  assert_blocked
}

@test "permission: allow if-then when all commands permitted" {
  run_hook_allow 'if test -f file; then cat file; fi' '["Bash(test:*)", "Bash(cat:*)"]'
  assert_allowed
}

@test "permission: block if-then when condition not permitted" {
  run_hook_block 'if rm file; then echo done; fi' '["Bash(echo:*)"]'
  assert_blocked
}
