#!/usr/bin/env bats
# Tests for Categories 5-6: Colons in Commands, Quoted Strings

load hook_test_helper

# =============================================================================
# Category 5: Colons in Commands
# =============================================================================

# --- Docker volume mounts ---

@test "parse: docker volume mount" {
  run_parse_commands 'docker run -v "$PWD:/app" image'
  assert_commands 'docker run -v "$PWD:/app" image'
}

@test "parse: docker volume mount with absolute paths" {
  run_parse_commands 'docker run -v /host:/container image'
  assert_commands "docker run -v /host:/container image"
}

@test "parse: docker named volume" {
  run_parse_commands 'docker run -v name:/path image'
  assert_commands "docker run -v name:/path image"
}

@test "parse: real bashly docker command" {
  # shellcheck disable=SC2016
  run_parse_commands 'docker run --rm -v "$PWD:/app" dannyben/bashly generate'
  # shellcheck disable=SC2016
  assert_commands 'docker run --rm -v "$PWD:/app" dannyben/bashly generate'
}

# --- Docker port mappings ---

@test "parse: docker port mapping" {
  run_parse_commands 'docker run -p 8080:80 nginx'
  assert_commands "docker run -p 8080:80 nginx"
}

@test "parse: docker port mapping with host IP" {
  run_parse_commands 'docker run -p 127.0.0.1:8080:80 nginx'
  assert_commands "docker run -p 127.0.0.1:8080:80 nginx"
}

@test "parse: docker same port mapping" {
  run_parse_commands 'docker run -p 3000:3000 image'
  assert_commands "docker run -p 3000:3000 image"
}

# --- Multiple colons ---

@test "parse: docker with volume, port, and tag" {
  run_parse_commands 'docker run -v /a:/b -p 1:2 img:tag'
  assert_commands "docker run -v /a:/b -p 1:2 img:tag"
}

@test "parse: docker pull with registry port and tag" {
  run_parse_commands 'docker pull registry.example.com:5000/image:latest'
  assert_commands "docker pull registry.example.com:5000/image:latest"
}

# --- Environment variables with colons ---

@test "parse: env var with colon in value" {
  run_parse_commands 'FOO=bar:baz command'
  assert_commands "command"
}

@test "parse: PATH-style colon-separated env var" {
  run_parse_commands 'PATH=/usr/bin:/bin ls'
  assert_commands "ls"
}

# --- Time specifications ---

@test "parse: at command with time" {
  run_parse_commands 'at 10:30 echo hello'
  assert_commands "at 10:30 echo hello"
}

@test "parse: date format with colons" {
  run_parse_commands 'date +%H:%M:%S'
  assert_commands "date +%H:%M:%S"
}

# --- URLs (colons in protocols) ---

@test "parse: curl HTTPS URL" {
  run_parse_commands 'curl https://example.com'
  assert_commands "curl https://example.com"
}

@test "parse: wget FTP URL with port" {
  run_parse_commands 'wget ftp://server:21/file'
  assert_commands "wget ftp://server:21/file"
}

@test "parse: git clone SSH URL" {
  run_parse_commands 'git clone git@github.com:user/repo.git'
  assert_commands "git clone git@github.com:user/repo.git"
}

# --- Permission validation for colons ---

@test "permission: allow docker command with colons" {
  run_hook_allow 'docker run -p 8080:80 nginx' '["Bash(docker run:*)"]'
  assert_allowed
}

# =============================================================================
# Category 6: Quoted Strings
# =============================================================================

# --- Double quotes ---

@test "parse: simple double quoted string" {
  run_parse_commands 'echo "hello world"'
  assert_commands 'echo "hello world"'
}

@test "parse: regex OR inside double quotes (literal)" {
  run_parse_commands 'grep -E "(int|long)"'
  assert_commands 'grep -E "(int|long)"'
}

@test "parse: escaped newline in double quotes" {
  run_parse_commands 'echo "line1\nline2"'
  assert_commands 'echo "line1\nline2"'
}

@test "parse: escaped tab in double quotes" {
  run_parse_commands 'echo "tab\there"'
  assert_commands 'echo "tab\there"'
}

@test "parse: escaped quotes inside double quotes" {
  run_parse_commands 'echo "quote: \"nested\""'
  assert_commands 'echo "quote: \"nested\""'
}

@test "parse: variable in double quotes" {
  run_parse_commands 'echo "$HOME"'
  assert_commands 'echo "$HOME"'
}

@test "parse: parameter expansion in double quotes" {
  # SKIP: shfmt/jq simplifies ${VAR:-default} to $VAR - loses default value syntax
  skip "Behavioral: parameter expansion simplified by shfmt AST"
  run_parse_commands 'echo "${VAR:-default}"'
  assert_commands 'echo "${VAR:-default}"'
}

# --- Single quotes ---

@test "parse: simple single quoted string" {
  run_parse_commands "echo 'hello world'"
  assert_commands "echo 'hello world'"
}

@test "parse: pattern in single quotes" {
  run_parse_commands "grep -E 'pattern'"
  assert_commands "grep -E 'pattern'"
}

@test "parse: literal dollar sign in single quotes" {
  run_parse_commands "echo '\$HOME'"
  assert_commands "echo '\$HOME'"
}

@test "parse: literal command substitution in single quotes" {
  run_parse_commands "echo '\$(cmd)'"
  assert_commands "echo '\$(cmd)'"
}

@test "parse: escaped single quote" {
  run_parse_commands "echo 'it'\\''s'"
  assert_commands "echo 'it'\\''s'"
}

# --- Mixed quotes ---

@test "parse: single inside double quotes" {
  run_parse_commands "echo \"he said 'hello'\""
  assert_commands "echo \"he said 'hello'\""
}

@test "parse: double inside single quotes" {
  run_parse_commands "echo 'she said \"hi\"'"
  assert_commands "echo 'she said \"hi\"'"
}

@test "parse: concatenated quotes" {
  run_parse_commands "echo \"foo\"'bar'\"baz\""
  assert_commands "echo \"foo\"'bar'\"baz\""
}

# --- Quotes with special characters ---

@test "parse: AND inside double quotes (literal)" {
  run_parse_commands 'echo "a && b"'
  assert_commands 'echo "a && b"'
}

@test "parse: semicolon inside double quotes (literal)" {
  run_parse_commands 'echo "a; b"'
  assert_commands 'echo "a; b"'
}

@test "parse: pipe inside double quotes (literal)" {
  run_parse_commands 'echo "a | b"'
  assert_commands 'echo "a | b"'
}

@test "parse: regex OR in single quotes (literal)" {
  run_parse_commands "grep 'pattern|other'"
  assert_commands "grep 'pattern|other'"
}

# --- Permission validation for quoted strings ---

@test "permission: allow echo with quoted special chars" {
  run_hook_allow 'echo "a && b | c"' '["Bash(echo:*)"]'
  assert_allowed
}

@test "permission: quoted pipe not parsed as separate command" {
  # Should only see echo, not a separate piped command
  run_hook_allow 'echo "ls | rm"' '["Bash(echo:*)"]'
  assert_allowed
}
