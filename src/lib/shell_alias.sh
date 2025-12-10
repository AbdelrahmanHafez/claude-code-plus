# Shell alias configuration for Claude Code
# Adds aliases to shell config files to set SHELL env var when running claude

# Marker comment to identify our alias block
ALIAS_MARKER="# Added by better-claude-code for shell alias"

# Note: CHEZMOI_MODIFIED_FILES is defined in settings.sh
# TARGET_FILE is set by get_config_target() to avoid subshell issues
TARGET_FILE=""

# --- Public API ---

# Configure shell alias in all detected shell configs
configure_shell_alias() {
  local shell_path="$1"
  local configured=false

  # Bash
  if [[ -f "$HOME/.bashrc" ]]; then
    configure_alias "bash" "$shell_path" "$HOME/.bashrc"
    configured=true
  fi

  # Zsh
  if [[ -f "$HOME/.zshrc" ]]; then
    configure_alias "zsh" "$shell_path" "$HOME/.zshrc"
    configured=true
  fi

  # Fish
  local fish_config="$HOME/.config/fish/config.fish"
  if [[ -f "$fish_config" ]]; then
    configure_alias "fish" "$shell_path" "$fish_config"
    configured=true
  fi

  if [[ "$configured" == false ]]; then
    warn "No shell config files found to configure"
    return 1
  fi
}

# --- Per-shell configuration ---

# Configure alias for a specific shell
# Args: shell_type (bash|zsh|fish), shell_path, config_file
configure_alias() {
  local shell_type="$1"
  local shell_path="$2"
  local config_file="$3"

  # Sets TARGET_FILE global (avoids subshell so CHEZMOI_MODIFIED_FILES persists)
  get_config_target "$config_file"
  local target_file="$TARGET_FILE"

  if alias_already_configured "$target_file"; then
    info "${shell_type^} alias already configured"
    return 0
  fi

  local alias_block
  alias_block=$(generate_alias "$shell_type" "$shell_path")

  append_to_config "$target_file" "$alias_block"
  success "Added claude alias to $(basename "$target_file")"
}

# --- Alias generators ---

generate_alias() {
  local shell_type="$1"
  local shell_path="$2"

  if [[ "$shell_type" == "fish" ]]; then
    cat <<EOF

$ALIAS_MARKER
function claude
  SHELL="$shell_path" command claude \$argv
end
EOF
  else
    # bash and zsh use identical syntax
    cat <<EOF

$ALIAS_MARKER
claude() {
  SHELL="$shell_path" command claude "\$@"
}
EOF
  fi
}

# --- Helpers ---

# Get the target file to write to (handles chezmoi)
# Sets TARGET_FILE global instead of echoing (to avoid subshell issues with array tracking)
get_config_target() {
  local config_file="$1"
  local relative_path="${config_file#$HOME/}"

  # Check if this specific file is managed by chezmoi
  if is_file_managed_by_chezmoi "$relative_path"; then
    local chezmoi_source
    chezmoi_source=$(chezmoi source-path "$config_file" 2>/dev/null)
    if [[ -n "$chezmoi_source" ]]; then
      # Track that we modified a chezmoi-managed file
      CHEZMOI_MODIFIED_FILES+=("$config_file")
      TARGET_FILE="$chezmoi_source"
      return
    fi
  fi

  TARGET_FILE="$config_file"
}

is_file_managed_by_chezmoi() {
  local relative_path="$1"

  if ! command -v chezmoi &>/dev/null; then
    return 1
  fi

  chezmoi source-path "$HOME/$relative_path" &>/dev/null
}

alias_already_configured() {
  local file="$1"
  grep -q "$ALIAS_MARKER" "$file" 2>/dev/null
}

append_to_config() {
  local file="$1"
  local content="$2"

  echo "$content" >> "$file"
}
