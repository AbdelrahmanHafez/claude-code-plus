main() {
  local non_interactive="${args_yes:-}"

  init_claude_paths

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
  local shell_path="${args_shell:-}"
  if [[ -z "$shell_path" ]]; then
    shell_path=$(find_modern_bash)
  fi
  local shell_name
  shell_name=$(basename "$shell_path")

  if prompt_yes_no "Configure Claude Code to run commands in $shell_name?" "Y"; then
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
  if [[ -n "${args_yes:-}" ]]; then
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
  step "Configuring shell for Claude Code commands"

  local shell_path="${args_shell:-}"

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

  info "Configuring Claude to use $shell_name ($shell_path)"

  # Set env.SHELL in settings.json (for when Claude fixes the bug)
  set_setting '.env.SHELL' "\"$shell_path\""

  # Add shell alias to shell config files (workaround until bug is fixed)
  configure_shell_alias "$shell_path"

  success "Claude Code will now run commands in $shell_name"
}

step_hook() {
  step "Installing hook to auto-approve allowed commands"

  local hook_file
  hook_file=$(get_hook_filepath)

  ensure_hooks_dir

  if [[ -f "$hook_file" ]]; then
    info "Hook already exists, updating..."
  fi

  get_hook_script_content > "$hook_file"
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
  # Print menu to /dev/tty so it's not captured by command substitution
  printf '\n' > /dev/tty
  printf "${BOLD}Choose installation mode:${NC}\n" > /dev/tty
  printf '\n' > /dev/tty
  printf "  ${GREEN}[1]${NC} ${BOLD}Recommended${NC} - Install everything with sensible defaults\n" > /dev/tty
  printf "      • Claude Code runs commands in modern bash (4.4+)\n" > /dev/tty
  printf "      • Auto-approve hook for compound commands\n" > /dev/tty
  printf "      • Safe read-only command permissions\n" > /dev/tty
  printf '\n' > /dev/tty
  printf "  ${BLUE}[2]${NC} ${BOLD}Custom${NC} - Choose what to install\n" > /dev/tty
  printf '\n' > /dev/tty

  local choice
  while true; do
    read -p "Enter choice [1/2]: " -n 1 -r choice
    printf '\n' > /dev/tty
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

# Replace $HOME with ~ for display
display_path() {
  echo "$1" | sed "s|$HOME|~|g"
}

print_completion() {
  echo ""
  echo "╔════════════════════════════════════════════╗"
  echo "║            Installation Complete!          ║"
  echo "╚════════════════════════════════════════════╝"
  echo ""
  success "Better Claude Code is now configured!"
  echo ""
  info "Settings file: $(display_path "$CLAUDE_SETTINGS")"
  if [[ -f "$(get_hook_filepath)" ]]; then
    info "Hook file: $(display_path "$(get_hook_filepath)")"
  fi
  echo ""
  # Prompt to apply chezmoi if any managed files were modified
  if has_chezmoi_modifications; then
    echo ""
    # Keep real paths for execution, display-friendly version for messages
    local chezmoi_targets="${CHEZMOI_MODIFIED_FILES[*]}"
    local chezmoi_targets_display
    chezmoi_targets_display="$(display_path "$chezmoi_targets")"
    local chezmoi_cmd="chezmoi apply $chezmoi_targets_display"
    if prompt_yes_no "Run $(cmd "$chezmoi_cmd") now?" "Y"; then
      # shellcheck disable=SC2086
      chezmoi apply $chezmoi_targets
      success "Chezmoi applied"
    else
      warn "Remember to run $(cmd "$chezmoi_cmd") before using Claude Code"
    fi
  fi
  echo ""
  local source_cmd
  case "$(basename "$SHELL")" in
    fish) source_cmd="source ~/.config/fish/config.fish" ;;
    zsh)  source_cmd="source ~/.zshrc" ;;
    *)    source_cmd="source ~/.bashrc" ;;
  esac
  info "Open a new terminal or run $(cmd "$source_cmd"), then run $(cmd "claude") to start."
  echo ""
  info "Review $(cmd "$(display_path "$CLAUDE_SETTINGS")") to remove any permissions you don't want auto-approved."
}

main
