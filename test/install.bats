#!/usr/bin/env bats

load 'test_helper'

setup() {
  setup_test_dir
}

teardown() {
  teardown_test_dir
}

# --- Basic functionality ---

@test "creates settings.json" {
  run_install
  [ "$status" -eq 0 ]
  assert_file_exists "$TEST_DIR/settings.json"
}

@test "creates hooks directory" {
  run_install
  [ "$status" -eq 0 ]
  assert_dir_exists "$TEST_DIR/hooks"
}

@test "creates hook file" {
  run_install
  [ "$status" -eq 0 ]
  assert_file_exists "$TEST_DIR/hooks/auto-approve-allowed-commands.sh"
}

@test "hook file is executable" {
  run_install
  [ "$status" -eq 0 ]
  assert_executable "$TEST_DIR/hooks/auto-approve-allowed-commands.sh"
}

@test "hook file has correct shebang" {
  run_install
  [ "$status" -eq 0 ]

  local first_line
  first_line=$(head -1 "$TEST_DIR/hooks/auto-approve-allowed-commands.sh")
  [ "$first_line" = "#!/usr/bin/env bash" ]
}

@test "hook file has CLAUDE_DIR baked in" {
  run_install
  [ "$status" -eq 0 ]

  grep -q "CLAUDE_DIR=\"$TEST_DIR\"" "$TEST_DIR/hooks/auto-approve-allowed-commands.sh"
}

# --- Shell configuration ---

@test "configures shell" {
  run_install
  [ "$status" -eq 0 ]

  local shell_value
  shell_value=$(jq -r '.env.SHELL' "$TEST_DIR/settings.json")
  [ -n "$shell_value" ]
  [ "$shell_value" != "null" ]
}

@test "uses custom shell when specified" {
  run_install --shell /bin/bash
  [ "$status" -eq 0 ]
  assert_json_value "$TEST_DIR/settings.json" '.env.SHELL' "/bin/bash"
}

@test "fails for non-existent shell" {
  run_install --shell /nonexistent/shell
  [ "$status" -ne 0 ]
}

# --- Hook configuration ---

@test "configures hook in settings.json" {
  run_install
  [ "$status" -eq 0 ]

  # Check hook config structure
  assert_json_value "$TEST_DIR/settings.json" '.hooks.PreToolUse[0].matcher' "Bash"
  assert_json_value "$TEST_DIR/settings.json" '.hooks.PreToolUse[0].hooks[0].type' "command"
}

@test "appends to existing Bash matcher instead of creating duplicate" {
  # Create settings with an existing Bash matcher that has a different hook
  cat > "$TEST_DIR/settings.json" <<'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "existing-hook.sh" }
        ]
      }
    ]
  }
}
EOF

  run_install
  [ "$status" -eq 0 ]

  # Should still have only ONE Bash matcher
  local bash_matcher_count
  bash_matcher_count=$(jq '[.hooks.PreToolUse[] | select(.matcher == "Bash")] | length' "$TEST_DIR/settings.json")
  [ "$bash_matcher_count" -eq 1 ]

  # The single Bash matcher should now have TWO hooks
  local hooks_count
  hooks_count=$(jq '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks | length' "$TEST_DIR/settings.json")
  [ "$hooks_count" -eq 2 ]

  # Verify both hooks are present
  jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.command == "existing-hook.sh")' "$TEST_DIR/settings.json"
  jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.command | contains("auto-approve-allowed-commands.sh"))' "$TEST_DIR/settings.json"
}

@test "preserves other matchers (Read, Write, etc.)" {
  # Create settings with multiple matchers
  cat > "$TEST_DIR/settings.json" <<'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read",
        "hooks": [{ "type": "command", "command": "read-hook.sh" }]
      },
      {
        "matcher": "Write",
        "hooks": [{ "type": "command", "command": "write-hook.sh" }]
      }
    ]
  }
}
EOF

  run_install
  [ "$status" -eq 0 ]

  # Should now have 3 matchers: Read, Write, Bash
  local matcher_count
  matcher_count=$(jq '.hooks.PreToolUse | length' "$TEST_DIR/settings.json")
  [ "$matcher_count" -eq 3 ]

  # Verify Read and Write matchers still exist
  jq -e '.hooks.PreToolUse[] | select(.matcher == "Read")' "$TEST_DIR/settings.json"
  jq -e '.hooks.PreToolUse[] | select(.matcher == "Write")' "$TEST_DIR/settings.json"
  jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash")' "$TEST_DIR/settings.json"
}

# --- Permissions ---

@test "adds permissions array" {
  run_install
  [ "$status" -eq 0 ]

  local count
  count=$(jq '.permissions.allow | length' "$TEST_DIR/settings.json")
  [ "$count" -gt 0 ]
}

@test "includes basic commands" {
  run_install
  [ "$status" -eq 0 ]

  assert_json_contains "$TEST_DIR/settings.json" '.permissions.allow' 'Bash(ls:*)'
  assert_json_contains "$TEST_DIR/settings.json" '.permissions.allow' 'Bash(cat:*)'
}

@test "includes git read-only commands" {
  run_install
  [ "$status" -eq 0 ]

  assert_json_contains "$TEST_DIR/settings.json" '.permissions.allow' 'Bash(git status:*)'
  assert_json_contains "$TEST_DIR/settings.json" '.permissions.allow' 'Bash(git diff:*)'
}

@test "includes jq" {
  run_install
  [ "$status" -eq 0 ]

  assert_json_contains "$TEST_DIR/settings.json" '.permissions.allow' 'Bash(jq:*)'
}

@test "preserves existing permissions" {
  # Create settings with existing custom permission
  cat > "$TEST_DIR/settings.json" <<'EOF'
{
  "permissions": {
    "allow": ["Bash(my-custom-command:*)"]
  }
}
EOF

  run_install
  [ "$status" -eq 0 ]

  # Custom permission should still exist
  assert_json_contains "$TEST_DIR/settings.json" '.permissions.allow' 'Bash(my-custom-command:*)'
  # And new permissions should be added
  assert_json_contains "$TEST_DIR/settings.json" '.permissions.allow' 'Bash(ls:*)'
}

@test "does not duplicate permissions on second run" {
  run_install
  [ "$status" -eq 0 ]

  local count_first
  count_first=$(jq '.permissions.allow | length' "$TEST_DIR/settings.json")

  # Run again
  run_install
  [ "$status" -eq 0 ]

  local count_second
  count_second=$(jq '.permissions.allow | length' "$TEST_DIR/settings.json")

  [ "$count_first" -eq "$count_second" ]
}

# --- Idempotency ---

@test "second run succeeds (idempotent)" {
  run_install
  [ "$status" -eq 0 ]

  # Run again
  run_install
  [ "$status" -eq 0 ]
}

@test "shows completion message" {
  run_install
  [ "$status" -eq 0 ]
  assert_output_contains "Installation Complete"
}

# --- Custom options ---

@test "respects CLAUDE_DIR_OVERRIDE env var" {
  local custom_dir="$TEST_DIR/custom-claude"
  mkdir -p "$custom_dir"

  local project_root
  project_root=$(get_project_root)
  CLAUDE_DIR_OVERRIDE="$custom_dir" run "$project_root/install.sh"

  [ "$status" -eq 0 ]
  assert_file_exists "$custom_dir/settings.json"
  assert_file_exists "$custom_dir/hooks/auto-approve-allowed-commands.sh"
}
