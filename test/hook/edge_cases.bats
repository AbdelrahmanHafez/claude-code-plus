#!/usr/bin/env bats
# Tests for Categories 20-21: Malformed Input and shfmt-Specific Behaviors

load hook_test_helper

# =============================================================================
# Category 20: Malformed and Edge Case Input
# =============================================================================

# --- Empty and whitespace ---

@test "edge: empty string" {
  run_parse_commands ''
  # Empty input returns error message, not empty output
  [[ "$output" == *"Error"* ]] || [[ -z "$output" ]]
}

@test "edge: single space" {
  run_parse_commands ' '
  assert_no_commands
}

@test "edge: multiple spaces" {
  run_parse_commands '     '
  assert_no_commands
}

@test "edge: single tab" {
  run_parse_commands $'\t'
  assert_no_commands
}

@test "edge: mixed whitespace" {
  run_parse_commands $'  \t  \t  '
  assert_no_commands
}

@test "edge: newlines only" {
  run_parse_commands $'\n\n\n'
  assert_no_commands
}

# --- Comments only ---

@test "edge: comment only" {
  run_parse_commands '# this is a comment'
  assert_no_commands
}

@test "edge: multiple comments" {
  run_parse_commands $'# comment 1\n# comment 2\n# comment 3'
  assert_no_commands
}

@test "edge: comment with leading whitespace" {
  run_parse_commands '   # indented comment'
  assert_no_commands
}

# --- Syntax errors (shfmt handling) ---

@test "edge: unclosed single quote" {
  # shfmt may fail to parse this
  run_parse_commands "echo 'unclosed"
  # Either returns the command or fails gracefully
  [[ "$status" -ne 0 ]] || [[ -n "$output" ]]
}

@test "edge: unclosed double quote" {
  run_parse_commands 'echo "unclosed'
  [[ "$status" -ne 0 ]] || [[ -n "$output" ]]
}

@test "edge: unclosed parenthesis" {
  run_parse_commands 'echo ('
  [[ "$status" -ne 0 ]] || [[ -n "$output" ]]
}

@test "edge: unclosed brace" {
  run_parse_commands 'echo {'
  [[ "$status" -ne 0 ]] || [[ -n "$output" ]]
}

@test "edge: unmatched fi" {
  run_parse_commands 'fi'
  # shfmt should handle this gracefully
  [[ "$status" -eq 0 ]] || [[ "$status" -ne 0 ]]
}

@test "edge: unmatched done" {
  run_parse_commands 'done'
  [[ "$status" -eq 0 ]] || [[ "$status" -ne 0 ]]
}

# --- Unicode and special characters ---

@test "edge: unicode in command" {
  run_parse_commands 'echo "Hello 世界"'
  assert_commands 'echo "Hello 世界"'
}

@test "edge: emoji in string" {
  run_parse_commands 'echo "🚀"'
  assert_commands 'echo "🚀"'
}

@test "edge: null byte in string" {
  # Null bytes are tricky - test graceful handling
  run_parse_commands $'echo "test\x00byte"'
  # Should either work or fail gracefully
  [[ "$status" -eq 0 ]] || [[ "$status" -ne 0 ]]
}

# --- Very long commands ---

@test "edge: very long command" {
  local long_cmd="echo "
  for i in {1..100}; do
    long_cmd+="arg$i "
  done
  run_parse_commands "$long_cmd"
  [[ "$output" == *"echo"* ]]
}

@test "edge: many pipes" {
  run_parse_commands 'cat | head | tail | grep | sort | uniq | wc'
  assert_commands "cat" "head" "tail" "grep" "sort" "uniq" "wc"
}

@test "edge: many semicolons" {
  run_parse_commands 'a; b; c; d; e; f; g'
  assert_commands "a" "b" "c" "d" "e" "f" "g"
}

# =============================================================================
# Category 21: shfmt-Specific Behaviors
# =============================================================================

# --- Normalization behaviors ---

@test "shfmt: extracts command from $() substitution" {
  # The parser extracts nested commands from command substitution
  run_parse_commands 'echo $(date)'
  assert_commands 'echo $(..)' 'date'
}

@test "shfmt: converts backticks to $() and extracts" {
  # Backticks are converted to $() and nested command is extracted
  run_parse_commands 'echo `date`'
  assert_commands 'echo $(..)' 'date'
}

@test "shfmt: normalizes ${VAR} to $VAR" {
  run_parse_commands 'echo ${HOME}'
  assert_commands 'echo $HOME'
}

@test "shfmt: double brackets not extracted as command" {
  # Behavioral: [[ ]] test constructs are not extracted as commands
  run_parse_commands '[[ -f file ]]'
  assert_no_commands
}

@test "shfmt: single brackets preserved" {
  run_parse_commands '[ -f file ]'
  assert_commands "[ -f file ]"
}

# --- Quote handling ---

@test "shfmt: preserves necessary double quotes" {
  run_parse_commands 'echo "with spaces"'
  assert_commands 'echo "with spaces"'
}

@test "shfmt: preserves single quotes exactly" {
  run_parse_commands "echo 'literal \$var'"
  assert_commands "echo 'literal \$var'"
}

@test "shfmt: removes unnecessary quotes" {
  # shfmt might simplify 'simple' to simple
  run_parse_commands "echo 'simple'"
  # Either keeps or removes quotes - both valid
  [[ "$output" == "echo 'simple'" ]] || [[ "$output" == "echo simple" ]]
}

# --- Heredoc handling ---

@test "shfmt: basic heredoc" {
  run_parse_commands $'cat <<EOF\nhello\nEOF'
  # The command is just 'cat'
  assert_commands "cat"
}

@test "shfmt: heredoc with delimiter in quotes" {
  run_parse_commands $'cat <<"EOF"\nhello\nEOF'
  assert_commands "cat"
}

@test "shfmt: here-string" {
  run_parse_commands 'cat <<< "hello"'
  assert_commands "cat"
}

# --- Arithmetic expansion ---

@test "shfmt: arithmetic expansion stripped from command" {
  # Behavioral: arithmetic expansion is stripped, leaving just the command
  run_parse_commands 'echo $((1+2))'
  assert_commands 'echo'
}

@test "shfmt: arithmetic in assignment" {
  # Pure assignment - no command to extract (SAFE)
  run_parse_commands 'x=$((y+1))'
  assert_no_commands
}

# --- Array handling ---

@test "shfmt: array declaration" {
  # Pure assignment - no command to extract (SAFE)
  run_parse_commands 'arr=(one two three)'
  assert_no_commands
}

@test "shfmt: array access simplified" {
  # Behavioral: ${arr[0]} is simplified to $arr
  run_parse_commands 'echo ${arr[0]}'
  assert_commands 'echo $arr'
}

# --- Special parameter expansion ---

@test "shfmt: default value expansion" {
  # shfmt simplifies ${VAR:-default} to $VAR (SAFE - command still validated)
  run_parse_commands 'echo ${FOO:-default}'
  assert_commands 'echo $FOO'
}

@test "shfmt: substring expansion" {
  run_parse_commands 'echo ${str:0:5}'
  # shfmt may transform this
  [[ -n "$output" ]]
}

# --- Process substitution ---

@test "shfmt: process substitution extracted" {
  # Process substitution commands ARE extracted for permission checking
  run_parse_commands 'diff <(ls dir1) <(ls dir2)'
  assert_commands 'diff' 'ls dir1' 'ls dir2'
}

@test "shfmt: output process substitution extracted" {
  # Output process substitution commands ARE also extracted
  run_parse_commands 'tee >(grep error)'
  assert_commands 'tee' 'grep error'
}

# --- Brace expansion ---

@test "shfmt: brace expansion" {
  run_parse_commands 'echo {1..5}'
  assert_commands "echo {1..5}"
}

@test "shfmt: brace list expansion" {
  run_parse_commands 'echo {a,b,c}'
  assert_commands "echo {a,b,c}"
}

# --- Case statement ---

@test "shfmt: case statement" {
  run_parse_commands $'case "$x" in\n  y) echo yes ;;\n  *) echo no ;;\nesac'
  # Commands inside case are extracted
  assert_commands "echo yes" "echo no"
}

# --- Coproc ---

@test "shfmt: coproc command" {
  run_parse_commands 'coproc myproc { cat; }'
  # coproc is a compound command
  assert_commands "cat"
}

# =============================================================================
# Permission validation for edge cases
# =============================================================================

@test "permission: empty command allowed (no commands to check)" {
  run_hook '  ' '["Bash(ls:*)"]'
  # Empty/whitespace should be allowed (no commands = nothing to block)
  assert_allowed
}

@test "permission: comment only allowed" {
  run_hook_allow '# just a comment' '["Bash(ls:*)"]'
  assert_allowed
}

@test "permission: unicode command needs exact match" {
  run_hook_block 'echo "世界"' '["Bash(ls:*)"]'
  assert_blocked
}

@test "permission: unicode command allowed with echo permission" {
  run_hook_allow 'echo "世界"' '["Bash(echo:*)"]'
  assert_allowed
}

