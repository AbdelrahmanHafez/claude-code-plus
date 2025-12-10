# Install the auto-approve-allowed-commands hook
# Usage: action_install_hook [claude_dir] [hook_prefix]
action_install_hook() {
  local claude_dir="${1:-}"
  local hook_prefix="${2:-}"

  init_claude_paths "$claude_dir" "$hook_prefix"

  step "Installing auto-approve-allowed-commands hook"

  ensure_hooks_dir
  _hook_install_script
  configure_hook_in_settings
  _hook_print_success
}

_hook_install_script() {
  local hook_file
  hook_file=$(get_hook_filepath)

  if [[ -f "$hook_file" ]]; then
    _hook_prompt_overwrite "$hook_file" || return 0
  fi

  info "Writing hook to $hook_file"
  # shellcheck disable=SC2153  # CLAUDE_DIR is set by init_claude_paths
  generate_hook_script "$CLAUDE_DIR" > "$hook_file"
  chmod +x "$hook_file"
  success "Hook script created"
}

_hook_prompt_overwrite() {
  local hook_file="$1"

  warn "Hook already exists at $hook_file"
  read -p "Overwrite? [y/N] " -n 1 -r
  echo ""

  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Skipping hook installation"
    return 1
  fi

  return 0
}

_hook_print_success() {
  echo ""
  success "auto-approve-allowed-commands hook installed and configured!"
  echo ""
  info "The hook will auto-approve piped commands like 'ls | grep foo'"
  info "when all individual commands are in your allowed permissions."
}
