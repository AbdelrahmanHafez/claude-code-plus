#!/usr/bin/env bash
# Hook to allow piped commands where ALL components are in the allowed Bash permissions.
# Claude Code's prefix matching doesn't handle pipes - this hook fixes that.
# Dynamically reads allowed commands from:
#   1. ~/.claude/settings.json (global)
#   2. .claude/settings.json (project shared)
#   3. .claude/settings.local.json (project local)
#
# Dependencies: shfmt, jq
#
# Usage: echo '{"tool_input":{"command":"ls | grep foo"}}' | auto-approve-allowed-commands.sh [OPTIONS]
#
# Options:
#   --debug                 Enable debug output to stderr
#   --permissions JSON      Use custom permissions instead of reading from settings files
#                           JSON format: '["Bash(ls:*)", "Bash(grep:*)"]'
#
# Examples:
#   # Normal usage (reads permissions from settings files)
#   echo '{"tool_input":{"command":"ls | grep foo"}}' | auto-approve-allowed-commands.sh
#
#   # Testing with custom permissions
#   echo '{"tool_input":{"command":"ls | grep foo"}}' | auto-approve-allowed-commands.sh --permissions '["Bash(ls:*)", "Bash(grep:*)"]'

set -euo pipefail

# Debug mode
DEBUG=false
NUL_DELIM=false
# Custom permissions for testing (JSON array like: '["Bash(ls:*)", "Bash(cat:*)"]')
CUSTOM_PERMISSIONS=""

debug() {
  if $DEBUG; then
    echo "[DEBUG] $*" >&2
  fi
}

# Extract prefixes from a JSON array of permissions (for testing)
# Input: '["Bash(ls:*)", "Bash(grep:*)", "Bash(git log:*)"]'
# Output: ls\ngrep\ngit log
extract_prefixes_from_json() {
  local json="$1"
  echo "$json" | jq -r '.[]? // empty' 2>/dev/null \
    | grep -E '^Bash\(' \
    | sed -E 's/^Bash\(//; s/(:\*)?\)$//'
}

# Extract allowed Bash command prefixes from a settings file
# Matches patterns like Bash(ls:*), Bash(git log:*), etc.
extract_prefixes_from_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    debug "Settings file not found: $file"
    return 0
  fi
  debug "Reading prefixes from: $file"
  jq -r '.permissions.allow[]? // empty' "$file" 2>/dev/null \
    | grep -E '^Bash\(' \
    | sed -E 's/^Bash\(//; s/(:\*)?\)$//'
}

# Find git root directory (project root)
find_git_root() {
  git rev-parse --show-toplevel 2>/dev/null
}

# Get all allowed prefixes from all settings files (or custom permissions if set for testing)
get_allowed_prefixes() {
  # If custom permissions are set (for testing), use those instead
  if [[ -n "$CUSTOM_PERMISSIONS" ]]; then
    debug "Using custom permissions: $CUSTOM_PERMISSIONS"
    extract_prefixes_from_json "$CUSTOM_PERMISSIONS"
    return
  fi

  local git_root
  git_root=$(find_git_root)

  {
    # Global settings
    extract_prefixes_from_file "$HOME/.claude/settings.json"

    # Project settings (from git root if available, otherwise cwd)
    if [[ -n "$git_root" ]]; then
      extract_prefixes_from_file "$git_root/.claude/settings.json"
      extract_prefixes_from_file "$git_root/.claude/settings.local.json"
    else
      extract_prefixes_from_file ".claude/settings.json"
      extract_prefixes_from_file ".claude/settings.local.json"
    fi
  } | sort -u
}

# Check if a command matches any allowed prefix
# full_command: the extracted command with all args (e.g., "git log --oneline")
# allowed_prefixes: array of allowed prefixes from settings (e.g., "git log", "grep")
is_command_allowed() {
  local full_command="$1"
  local -n prefixes_ref=$2  # nameref to array

  for allowed in "${prefixes_ref[@]}"; do
    # Check if command starts with the allowed prefix
    # "git log --oneline" matches "git log" and "git"
    # "grep -E pattern" matches "grep"
    # "python3 .claude/skills/foo/bar.py" matches "python3 .claude/skills:*"
    if [[ "$full_command" == "$allowed" ]] || [[ "$full_command" == "$allowed "* ]] || [[ "$full_command" == "$allowed/"* ]]; then
      debug "ALLOWED: '$full_command' (matches '$allowed')"
      return 0
    fi
  done

  debug "BLOCKED: '$full_command' (no matching prefix)"
  return 1
}

main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --debug)
        DEBUG=true
        shift
        ;;
      --permissions)
        CUSTOM_PERMISSIONS="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  # Check for required dependencies
  if ! command -v jq &>/dev/null; then
    debug "jq not found, falling through to normal permission check"
    exit 0
  fi

  # Read the command from stdin (hook input is JSON)
  input=$(cat)
  debug "Input JSON: $input"
  command=$(echo "$input" | jq -r '.tool_input.command // empty')
  debug "Extracted command:"
  debug "$command"

  # Exit early if no command
  if [[ -z "$command" ]]; then
    debug "No command found, exiting"
    exit 0
  fi

  # Load allowed prefixes into array
  mapfile -t allowed_prefixes < <(get_allowed_prefixes)
  debug "Loaded ${#allowed_prefixes[@]} allowed prefixes"

  # If no prefixes (no Bash permissions), exit without allowing
  if [[ ${#allowed_prefixes[@]} -eq 0 ]]; then
    debug "No Bash permissions found, exiting"
    exit 0
  fi

  # Extract commands using built-in parser (NUL-delimited for multi-line command support)
  NUL_DELIM=true
  mapfile -d '' extracted_commands < <(extract_commands_from_string "$command") || {
    debug "Command parsing failed"
    debug "Falling through to normal permission check"
    exit 0
  }
  debug "Extracted ${#extracted_commands[@]} commands:"
  for cmd in "${extracted_commands[@]}"; do
    debug "  - $cmd"
  done

  # Check if no commands were found (empty input or only comments)
  if [[ ${#extracted_commands[@]} -eq 0 ]] || [[ -z "${extracted_commands[0]}" ]]; then
    debug "No commands found in input, allowing"
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
    exit 0
  fi

  # Check each command against allowed prefixes
  all_allowed=true
  for full_command in "${extracted_commands[@]}"; do
    [[ -z "$full_command" ]] && continue

    if ! is_command_allowed "$full_command" allowed_prefixes; then
      all_allowed=false
      break
    fi
  done

  if $all_allowed; then
    debug "Decision: ALLOW (all commands passed)"
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
  else
    debug "Decision: BLOCK (falling through to normal permission check)"
  fi

  exit 0
}
# shell-commands - Extract individual commands from a shell command string
#
# DESCRIPTION
#   Parses a shell command string and outputs each individual command on a
#   separate line. Uses shfmt for proper shell parsing, handling all shell
#   syntax correctly.
#
# USAGE
#   shell-commands [OPTIONS] [COMMAND]
#   echo "COMMAND" | shell-commands [OPTIONS]
#
# OPTIONS
#   -h, --help     Show this help message
#   -d, --debug    Enable debug output to stderr
#   -0, --null     Use NUL character as delimiter instead of newline
#                  (for programmatic use with: mapfile -d '' array < <(...))
#
# SUPPORTED SYNTAX
#   - Pipes:              cmd1 | cmd2 | cmd3
#   - And/Or:             cmd1 && cmd2 || cmd3
#   - Semicolons:         cmd1; cmd2; cmd3
#   - Newlines:           cmd1
#                         cmd2
#   - Line continuations: cmd1 \
#                           --flag | cmd2
#   - Pipe continuations: cmd1 |
#                           cmd2
#   - Comments:           cmd1  # inline comment
#                         # standalone comment
#   - Quoted strings:     grep -E "pattern|with|pipes" file
#   - Single quotes:      grep -E 'pattern' file
#   - Subshells:          (cmd1; cmd2) | cmd3
#   - Command substitution: echo $(cmd1 | cmd2)
#   - Variable expansion: echo $HOME
#   - bash -c / sh -c:    bash -c 'cmd1 | cmd2' (recursively expanded)
#
# QUOTE PRESERVATION
#   Quoted strings are preserved in output exactly as they appear in input.
#   Double quotes: grep -E "(int|long)" -> grep -E "(int|long)"
#   Single quotes: grep 'pattern' -> grep 'pattern'
#
# MALFORMED INPUT
#   If a newline breaks a command in the wrong place (e.g., between a flag
#   and its argument), shfmt will parse it as separate statements. This is
#   correct behavior - the input is invalid shell syntax.
#
#   Example of malformed input:
#     grep -E
#        "pattern"    <- This becomes a separate "command"
#
#   Correct alternatives:
#     grep -E "pattern"              <- single line
#     grep -E \
#        "pattern"                   <- backslash continuation
#     grep -E |
#        other_cmd                   <- pipe at end continues
#
# OUTPUT
#   Each command is printed on a separate line with all its arguments.
#   Only the command and arguments are printed, not the operators.
#
# EXAMPLES
#   $ shell-commands 'ls -la | grep foo | head -5'
#   ls -la
#   grep foo
#   head -5
#
#   $ shell-commands 'git status && git add . && git commit -m "msg"'
#   git status
#   git add .
#   git commit -m "msg"
#
#   $ echo 'grep -E "(int|long)" file.cs | head' | shell-commands
#   grep -E "(int|long)" file.cs
#   head
#
# DEPENDENCIES
#   - shfmt (brew install shfmt)
#   - jq (brew install jq)
#
# EXIT CODES
#   0 - Success
#   1 - Parse error or invalid input
#   2 - Missing dependencies
#

show_help() {
  sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
}

# Check dependencies
check_deps() {
  local missing=()
  command -v shfmt &>/dev/null || missing+=(shfmt)
  command -v jq &>/dev/null || missing+=(jq)

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Error: Missing dependencies: ${missing[*]}" >&2
    echo "Install with: brew install ${missing[*]}" >&2
    exit 2
  fi
}

# jq filter to extract commands from shfmt AST
# This walks the entire AST and extracts all CallExpr nodes
# Preserves quoting style from the original command
read -r -d '' JQ_FILTER << 'JQEOF' || true
# Recursively get string value from any word part, preserving quotes
def get_part_value:
  if (type == "object" | not) then ""
  elif .Type == "Lit" then .Value // ""
  elif .Type == "DblQuoted" then
    "\"" + ([.Parts[]? | get_part_value] | join("")) + "\""
  elif .Type == "SglQuoted" then
    "'" + (.Value // "") + "'"
  elif .Type == "ParamExp" then
    "$" + (.Param.Value // "")
  elif .Type == "CmdSubst" then
    # Represent command substitution as placeholder - nested commands extracted separately
    "$(..)"
  else
    ""
  end;

# Recursively find all CmdSubst and ProcSubst nodes in word parts (handles DblQuoted nesting)
def find_cmd_substs:
  if type == "object" then
    if .Type == "CmdSubst" or .Type == "ProcSubst" then .
    elif .Type == "DblQuoted" then .Parts[]? | find_cmd_substs
    elif .Parts then .Parts[]? | find_cmd_substs
    else empty
    end
  elif type == "array" then .[] | find_cmd_substs
  else empty
  end;

# Get full argument value (may have multiple parts concatenated)
def get_arg_value:
  [.Parts[]? | get_part_value] | join("");

# Get full command string from CallExpr
def get_command_string:
  if .Type == "CallExpr" and .Args then
    [.Args[] | get_arg_value] | map(select(length > 0)) | join(" ")
  else
    empty
  end;

# Recursively find and extract all commands
def extract_commands:
  if type == "object" then
    if .Type == "CallExpr" then
      get_command_string,
      # Also extract nested command substitutions (including inside DblQuoted)
      (.Args[]? | find_cmd_substs | .Stmts[]? | extract_commands)
    elif .Type == "BinaryCmd" then
      (.X | extract_commands),
      (.Y | extract_commands)
    elif .Type == "Subshell" or .Type == "Block" then
      (.Stmts[]? | extract_commands)
    elif .Type == "CmdSubst" then
      (.Stmts[]? | extract_commands)
    elif .Type == "IfClause" then
      (.Cond[]? | extract_commands),
      (.Then[]? | extract_commands),
      (.Else | extract_commands)
    elif .Type == "WhileClause" or .Type == "UntilClause" then
      (.Cond[]? | extract_commands),
      (.Do[]? | extract_commands)
    elif .Type == "ForClause" then
      # Extract from loop iterator (e.g., `for i in $(cmd)`)
      (.Loop.Items[]? | find_cmd_substs | .Stmts[]? | extract_commands),
      (.Do[]? | extract_commands)
    elif .Type == "CaseClause" then
      (.Items[]?.Stmts[]? | extract_commands)
    elif .Cmd then
      (.Cmd | extract_commands)
    elif .Stmts then
      (.Stmts[] | extract_commands)
    else
      (.[] | extract_commands)
    end
  elif type == "array" then
    (.[] | extract_commands)
  else
    empty
  end;

extract_commands | select(length > 0)
JQEOF

# Normalize shfmt-incompatible patterns
# shfmt can't parse [[ ! X =~ Y ]] but can parse ! [[ X =~ Y ]]
normalize_for_shfmt() {
  local cmd="$1"
  # Transform [[ ! ... =~ ... ]] to ! [[ ... =~ ... ]]
  # Also handle \! (escaped bang from some shells)
  # Use perl for more reliable regex with non-greedy matching
  echo "$cmd" | perl -pe 's/\[\[\s*\\?!\s+(.+?)\s+=~\s*/! [[ $1 =~ /g'
}

# Extract raw commands from AST (internal, always newline-separated)
extract_commands_raw() {
  local cmd="$1"
  local ast

  debug "Parsing: $cmd"

  # Normalize patterns that shfmt can't handle
  cmd=$(normalize_for_shfmt "$cmd")
  debug "Normalized: $cmd"

  # Parse with shfmt (use bash dialect for bash-specific syntax like =~)
  if ! ast=$(echo "$cmd" | shfmt -ln bash -tojson 2>&1); then
    debug "Parse error: $ast"
    echo "Parse error: $ast" >&2
    return 1
  fi

  debug "AST parsed successfully"

  # Extract commands using jq (always newline-separated internally)
  echo "$ast" | jq -r "$JQ_FILTER" 2>/dev/null
}

# Check if a command is "bash -c" or "sh -c" and extract the inner command
# Returns the inner command string if it matches, empty otherwise
# Handles:
#   - bash -c 'cmd' / sh -c 'cmd'
#   - /bin/bash -c 'cmd' / /usr/bin/bash -c 'cmd' (absolute paths)
#   - env bash -c 'cmd' / env sh -c 'cmd' (env prefix)
#   - env /bin/bash -c 'cmd' (env with absolute path)
get_shell_c_inner() {
  local cmd="$1"

  # Pattern components:
  # - Optional 'env ' prefix
  # - Optional path prefix (e.g., /bin/, /usr/bin/)
  # - bash or sh
  # - -c flag with optional space
  # - quoted string
  # Note: Using separate checks for clarity and to avoid complex regex escaping

  # Strip optional 'env ' prefix first
  local stripped="$cmd"
  if [[ "$cmd" =~ ^env[[:space:]]+ ]]; then
    stripped="${cmd#env }"
    stripped="${stripped# }"  # Remove any extra spaces
  fi

  # Strip optional path prefix (e.g., /bin/, /usr/bin/)
  if [[ "$stripped" =~ ^/[^[:space:]]*/(.+)$ ]]; then
    stripped="${BASH_REMATCH[1]}"
  fi

  # Now match: bash -c '...' or sh -c '...'
  if [[ "$stripped" =~ ^(bash|sh)[[:space:]]+-c[[:space:]]*[\'\"](.*)[\'\"]$ ]]; then
    echo "${BASH_REMATCH[2]}"
  elif [[ "$stripped" =~ ^(bash|sh)[[:space:]]+-c[\'\"](.*)[\'\"]$ ]]; then
    echo "${BASH_REMATCH[2]}"
  fi
}

# Main extraction function - handles bash -c recursively
extract_commands_from_string() {
  local cmd="$1"
  local raw_commands

  debug "Input command: $cmd"

  # Get raw commands
  raw_commands=$(extract_commands_raw "$cmd") || return 1

  # Process each command, recursively expanding bash -c / sh -c
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    local inner
    inner=$(get_shell_c_inner "$line")

    if [[ -n "$inner" ]]; then
      debug "Found shell -c, recursing into: $inner"
      # Recursively extract commands from the inner script
      extract_commands_from_string "$inner"
    else
      # Output the command with appropriate delimiter
      if $NUL_DELIM; then
        printf '%s\0' "$line"
      else
        echo "$line"
      fi
    fi
  done <<< "$raw_commands"
}

parse_commands() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        show_help
        exit 0
        ;;
      -d|--debug)
        DEBUG=true
        shift
        ;;
      -0|--null)
        NUL_DELIM=true
        shift
        ;;
      --)
        shift
        break
        ;;
      -*)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
      *)
        break
        ;;
    esac
  done

  check_deps

  # Get command from argument or stdin
  if [[ $# -gt 0 ]]; then
    command_str="$*"
  else
    command_str=$(cat)
  fi

  if [[ -z "$command_str" ]]; then
    echo "Error: No command provided" >&2
    exit 1
  fi

  extract_commands_from_string "$command_str"
}

case "${1:-}" in
	parse_commands)
		shift
		parse_commands "$@"
		;;
	*)
		main "$@"
		;;
esac