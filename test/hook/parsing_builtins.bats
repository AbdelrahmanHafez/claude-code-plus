#!/usr/bin/env bats
# Tests for Categories 13-15: Special Commands, Builtins, Functions, Paths

load hook_test_helper

# =============================================================================
# Category 13: Builtin Commands
# =============================================================================

@test "parse: cd command" {
  run_parse_commands 'cd /tmp'
  assert_commands "cd /tmp"
}

@test "parse: cd with variable" {
  run_parse_commands 'cd $HOME'
  assert_commands 'cd $HOME'
}

@test "parse: pushd command" {
  run_parse_commands 'pushd /tmp'
  assert_commands "pushd /tmp"
}

@test "parse: popd command" {
  run_parse_commands 'popd'
  assert_commands "popd"
}

@test "parse: source command" {
  run_parse_commands 'source ~/.bashrc'
  assert_commands "source ~/.bashrc"
}

@test "parse: dot source command" {
  run_parse_commands '. ~/.bashrc'
  assert_commands ". ~/.bashrc"
}

@test "parse: eval command" {
  # Eval content should be extracted for permission checking
  run_parse_commands 'eval "ls -la"'
  assert_commands 'eval "ls -la"'
}

@test "parse: exec command" {
  run_parse_commands 'exec bash'
  assert_commands "exec bash"
}

@test "parse: read command" {
  run_parse_commands 'read -p "Enter: " var'
  assert_commands 'read -p "Enter: " var'
}

@test "parse: type command" {
  run_parse_commands 'type ls'
  assert_commands "type ls"
}

@test "parse: hash command" {
  run_parse_commands 'hash -r'
  assert_commands "hash -r"
}

@test "parse: alias command" {
  run_parse_commands 'alias ll="ls -la"'
  assert_commands 'alias ll="ls -la"'
}

@test "parse: unalias command" {
  run_parse_commands 'unalias ll'
  assert_commands "unalias ll"
}

@test "parse: set command" {
  run_parse_commands 'set -e'
  assert_commands "set -e"
}

@test "parse: unset command" {
  run_parse_commands 'unset VAR'
  assert_commands "unset VAR"
}

@test "parse: trap command" {
  run_parse_commands 'trap "echo done" EXIT'
  assert_commands 'trap "echo done" EXIT'
}

@test "parse: return command" {
  run_parse_commands 'return 0'
  assert_commands "return 0"
}

@test "parse: exit command" {
  run_parse_commands 'exit 1'
  assert_commands "exit 1"
}

@test "parse: true command" {
  run_parse_commands 'true'
  assert_commands "true"
}

@test "parse: false command" {
  run_parse_commands 'false'
  assert_commands "false"
}

@test "parse: colon (noop) command" {
  run_parse_commands ':'
  assert_commands ":"
}

@test "parse: test command" {
  run_parse_commands 'test -f file.txt'
  assert_commands "test -f file.txt"
}

@test "parse: bracket test" {
  run_parse_commands '[ -f file.txt ]'
  assert_commands "[ -f file.txt ]"
}

# =============================================================================
# Category 14: Function Definitions
# =============================================================================

# NOTE: Function definitions are NOT extracted as commands by the parser
# Only the function body commands should be extracted

@test "parse: simple function definition" {
  # skip "Behavioral: function definitions not extracted as commands"
  run_parse_commands 'foo() { echo hello; }'
  assert_commands "echo hello"
}

@test "parse: function keyword syntax" {
  # skip "Behavioral: function definitions not extracted as commands"
  run_parse_commands 'function foo { echo hello; }'
  assert_commands "echo hello"
}

@test "parse: function with multiple commands" {
  # skip "Behavioral: function definitions not extracted as commands"
  run_parse_commands 'foo() { cmd1; cmd2; cmd3; }'
  assert_commands "cmd1" "cmd2" "cmd3"
}

# =============================================================================
# Category 15: Path and Command Resolution
# =============================================================================

# --- Absolute paths ---

@test "parse: absolute path command" {
  run_parse_commands '/usr/bin/ls'
  assert_commands "/usr/bin/ls"
}

@test "parse: absolute path with args" {
  run_parse_commands '/usr/bin/git status'
  assert_commands "/usr/bin/git status"
}

@test "parse: home-relative path" {
  run_parse_commands '~/bin/script.sh'
  assert_commands "~/bin/script.sh"
}

@test "parse: dot-relative path" {
  run_parse_commands './script.sh'
  assert_commands "./script.sh"
}

@test "parse: parent-relative path" {
  run_parse_commands '../script.sh'
  assert_commands "../script.sh"
}

# --- Path with special characters ---

@test "parse: path with spaces (quoted)" {
  # Behavioral: shfmt preserves quotes around paths with spaces
  run_parse_commands '"/path/with spaces/cmd"'
  assert_commands '"/path/with spaces/cmd"'
}

@test "parse: path with spaces (escaped)" {
  run_parse_commands '/path/with\ spaces/cmd'
  assert_commands "/path/with\\ spaces/cmd"
}

# --- env command ---

@test "parse: env command" {
  run_parse_commands 'env'
  assert_commands "env"
}

@test "parse: env with command" {
  # env followed by a command should extract the command
  run_parse_commands 'env ls'
  assert_commands "env ls"
}

@test "parse: env with var and command" {
  # env setting a var then running command
  run_parse_commands 'env FOO=bar ls'
  assert_commands "env FOO=bar ls"
}

# --- which/command/type ---

@test "parse: which command" {
  run_parse_commands 'which python'
  assert_commands "which python"
}

@test "parse: command builtin" {
  run_parse_commands 'command ls'
  assert_commands "command ls"
}

@test "parse: command -v" {
  run_parse_commands 'command -v python'
  assert_commands "command -v python"
}

# =============================================================================
# Permission validation for builtins and paths
# =============================================================================

@test "permission: cd allowed with permission" {
  run_hook_allow 'cd /tmp' '["Bash(cd:*)"]'
  assert_allowed
}

@test "permission: cd blocked without permission" {
  run_hook_block 'cd /tmp' '["Bash(ls:*)"]'
  assert_blocked
}

@test "permission: source blocked without permission" {
  run_hook_block 'source ~/.bashrc' '["Bash(ls:*)"]'
  assert_blocked
}

@test "permission: absolute path matches command name" {
  # /usr/bin/ls should NOT match Bash(ls:*) - it's a different command string
  run_hook_block '/usr/bin/ls' '["Bash(ls:*)"]'
  assert_blocked
}

@test "permission: absolute path needs exact permission" {
  run_hook_allow '/usr/bin/ls' '["Bash(/usr/bin/ls:*)"]'
  assert_allowed
}

@test "permission: home path expansion" {
  # ~/bin/script needs Bash(~/bin:*) or similar
  run_hook_allow '~/bin/script.sh' '["Bash(~/bin:*)"]'
  assert_allowed
}

@test "permission: relative path" {
  run_hook_allow './script.sh' '["Bash(./script.sh:*)"]'
  assert_allowed
}

@test "permission: env command with target" {
  # env ls should need permission for the whole thing
  run_hook_allow 'env ls' '["Bash(env:*)"]'
  assert_allowed
}

@test "permission: command builtin with target" {
  run_hook_allow 'command ls' '["Bash(command:*)"]'
  assert_allowed
}

