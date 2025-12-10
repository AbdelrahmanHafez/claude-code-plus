main() {
  local claude_dir="${args['--claude-dir']:-}"
  local non_interactive="${args['--yes']:-}"

  init_claude_paths "$claude_dir"

  print_banner

  step_deps

  local mode="recommended"
  if [[ -z "$non_interactive" ]]; then
    mode=$(prompt_install_mode)
  fi

  if [[ "$mode" == "recommended" ]]; then
    run_recommended_install
  else
    run_custom_install
  fi

  print_completion
}

# --- Install modes ---

run_recommended_install() {
  info "Installing with recommended settings..."
  echo ""

  step_shell
  step_hook
  step_permissions
}

run_custom_install() {
  info "Custom installation..."
  echo ""

  # Shell selection
  if prompt_yes_no "Set which shell Claude Code uses?" "Y"; then
    step_shell
  else
    info "Skipping shell configuration"
  fi

  # Hook installation
  if prompt_yes_no "Auto-approve piped commands that match allowed patterns?" "Y"; then
    step_hook
  else
    info "Skipping hook installation"
  fi

  # Permissions
  if prompt_yes_no "Pre-approve common safe commands (ls, git status, grep, etc.)?" "Y"; then
    step_permissions
  else
    info "Skipping permissions"
  fi
}

# --- Steps ---

step_deps() {
  step "Checking dependencies"

  if check_all_deps; then
    success "All dependencies present"
    return 0
  fi

  warn "Some dependencies missing"

  # Non-interactive mode: auto-install
  if [[ -n "${args['--yes']:-}" ]]; then
    install_missing_deps || exit 1
    return
  fi

  read -p "Install missing dependencies? [Y/n] " -n 1 -r
  echo ""

  if [[ $REPLY =~ ^[Nn]$ ]]; then
    error "Cannot continue without dependencies"
    exit 1
  fi

  install_missing_deps || exit 1
}

step_shell() {
  step "Configuring shell"

  local shell_path="${args['--shell']:-}"

  # Default to modern bash if not specified
  if [[ -z "$shell_path" ]]; then
    if ! shell_path=$(find_modern_bash); then
      error "Modern bash (4.4+) not found"
      info "Install with: brew install bash"
      info "Or specify a shell with: --shell /path/to/shell"
      exit 1
    fi
  fi

  local shell_name
  shell_name=$(basename "$shell_path")

  if [[ ! -x "$shell_path" ]]; then
    error "Shell not found or not executable: $shell_path"
    info "Use --shell to specify a valid shell path"
    exit 1
  fi

  local current_shell
  current_shell=$(get_setting '.env.SHELL')

  if [[ "$current_shell" == "$shell_path" ]]; then
    success "Shell already set to $shell_name"
    return 0
  fi

  info "Configuring Claude to use $shell_name ($shell_path)"
  set_setting '.env.SHELL' "\"$shell_path\""
  success "Shell configured"
}

step_hook() {
  step "Installing hook to auto-approve allowed commands"

  local hook_file
  hook_file=$(get_hook_filepath)

  ensure_hooks_dir

  if [[ -f "$hook_file" ]]; then
    info "Hook already exists, updating..."
  fi

  # shellcheck disable=SC2153
  generate_hook_script "$CLAUDE_DIR" > "$hook_file"
  chmod +x "$hook_file"
  success "Hook installed"

  configure_hook_in_settings
}

step_permissions() {
  step "Adding safe permissions"

  local added=0

  for perm in "${DEFAULT_PERMISSIONS[@]}"; do
    if ! array_contains '.permissions.allow' "\"$perm\""; then
      array_add '.permissions.allow' "\"$perm\""
      ((added++)) || true
    fi
  done

  if [[ $added -eq 0 ]]; then
    success "All permissions already configured"
  else
    success "Added $added safe command permissions"
  fi
}

# --- Output ---

print_banner() {
  echo ""
  echo "╔════════════════════════════════════════════╗"
  echo "║       Better Claude Code Installer         ║"
  echo "╚════════════════════════════════════════════╝"
  echo ""
}

# --- Prompts ---

prompt_install_mode() {
  echo "Choose installation mode:"
  echo ""
  echo "  [1] Recommended - Install everything with sensible defaults"
  echo "      • Modern bash (4.4+) as shell"
  echo "      • Auto-approve hook for compound commands"
  echo "      • Safe read-only command permissions"
  echo ""
  echo "  [2] Custom - Choose what to install"
  echo ""

  local choice
  while true; do
    read -p "Enter choice [1/2]: " -n 1 -r choice
    echo ""
    case "$choice" in
      1) echo "recommended"; return ;;
      2) echo "custom"; return ;;
      "") echo "recommended"; return ;;  # Default to recommended
      *) warn "Please enter 1 or 2" ;;
    esac
  done
}

prompt_yes_no() {
  local prompt="$1"
  local default="${2:-Y}"  # Y or N

  local hint
  if [[ "$default" == "Y" ]]; then
    hint="[Y/n]"
  else
    hint="[y/N]"
  fi

  local reply
  read -p "$prompt $hint " -n 1 -r reply
  echo ""

  if [[ -z "$reply" ]]; then
    reply="$default"
  fi

  [[ "$reply" =~ ^[Yy]$ ]]
}

print_completion() {
  echo ""
  echo "╔════════════════════════════════════════════╗"
  echo "║            Installation Complete!          ║"
  echo "╚════════════════════════════════════════════╝"
  echo ""
  success "Better Claude Code is now configured!"
  echo ""
  info "Settings file: $CLAUDE_SETTINGS"
  if [[ -f "$(get_hook_filepath)" ]]; then
    info "Hook file: $(get_hook_filepath)"
  fi
  echo ""
  info "Start a new Claude Code session to apply changes."
}

main
