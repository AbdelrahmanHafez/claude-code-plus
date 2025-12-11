#!/usr/bin/env bash
# Build script for better-claude-code
# Generates embedded content and runs bashly

set -euo pipefail

cd "$(dirname "$0")"

echo "Generating hook content..."
./scripts/generate-hook-content.sh

echo "Running bashly generate..."
if command -v bashly &>/dev/null; then
  bashly generate
else
  docker run --rm -v "$PWD:/app" dannyben/bashly generate
fi

echo "Adding POSIX bootstrap..."
# Prepend POSIX-compatible bootstrap that re-execs with modern bash if needed
BOOTSTRAP='#!/bin/sh
# POSIX bootstrap: re-exec with modern bash if needed

# Colors (POSIX-compatible)
if [ -t 1 ]; then
  _RED="\033[0;31m"
  _GREEN="\033[0;32m"
  _YELLOW="\033[0;33m"
  _BLUE="\033[0;34m"
  _BOLD="\033[1m"
  _NC="\033[0m"
else
  _RED="" _GREEN="" _YELLOW="" _BLUE="" _BOLD="" _NC=""
fi

_info() { printf "${_BLUE}i${_NC} %s\\n" "$*"; }
_success() { printf "${_GREEN}+${_NC} %s\\n" "$*"; }
_error() { printf "${_RED}x${_NC} %s\\n" "$*" >&2; }
_cmd() { printf "${_BOLD}${_BLUE}%s${_NC}" "$1"; }

_prompt_yn() {
  # Usage: _prompt_yn "Question" && echo "yes" || echo "no"
  printf "${_YELLOW}?${_NC} %s [Y/n] " "$1"
  read -r _answer </dev/tty
  case "$_answer" in
    [nN]*) return 1 ;;
    *) return 0 ;;
  esac
}

_need_modern_bash() {
  [ -z "$BASH_VERSION" ] && return 0
  _major=$(echo "$BASH_VERSION" | cut -d. -f1)
  [ "$_major" -lt 4 ] && return 0
  return 1
}

_ensure_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi
  _info "Homebrew is not installed."
  if _prompt_yn "Install Homebrew?"; then
    _info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add Homebrew to PATH for this session
    if [ -x /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
    if command -v brew >/dev/null 2>&1; then
      _success "Homebrew installed successfully."
      return 0
    else
      _error "Failed to install Homebrew."
      return 1
    fi
  else
    _error "Homebrew is required. Please install it from https://brew.sh"
    return 1
  fi
}

_ensure_modern_bash() {
  for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    if [ -x "$_b" ]; then
      return 0
    fi
  done
  _info "bash 4.4+ is required but not found."
  if _prompt_yn "Install modern bash via Homebrew? ($(_cmd "brew install bash"))"; then
    _info "Installing bash..."
    brew install bash
    if [ -x /opt/homebrew/bin/bash ] || [ -x /usr/local/bin/bash ]; then
      _success "bash installed successfully."
      return 0
    else
      _error "Failed to install bash."
      return 1
    fi
  else
    _error "bash 4.4+ is required. Install with: $(_cmd "brew install bash")"
    return 1
  fi
}

if _need_modern_bash; then
  # Check for existing modern bash first
  for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    if [ -x "$_b" ]; then
      printf "Detected bash %s, using modern bash at %s...\\n" "$BASH_VERSION" "$_b"
      _tmp=$(mktemp)
      trap "rm -f \"$_tmp\"" EXIT
      curl -fsSL "https://raw.githubusercontent.com/AbdelrahmanHafez/better-claude-code/main/install.sh" -o "$_tmp"
      exec "$_b" "$_tmp" "$@"
    fi
  done

  # No modern bash found, try to install dependencies
  _ensure_homebrew || exit 1
  _ensure_modern_bash || exit 1

  # Try again after installation
  for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    if [ -x "$_b" ]; then
      _tmp=$(mktemp)
      trap "rm -f \"$_tmp\"" EXIT
      curl -fsSL "https://raw.githubusercontent.com/AbdelrahmanHafez/better-claude-code/main/install.sh" -o "$_tmp"
      exec "$_b" "$_tmp" "$@"
    fi
  done

  _error "Could not find modern bash after installation."
  exit 1
fi
# === End bootstrap ===

'

# Remove bashly's shebang and prepend bootstrap
tail -n +2 install.sh > install.sh.tmp
echo "$BOOTSTRAP" | cat - install.sh.tmp > install.sh
rm install.sh.tmp

echo "Build complete: install.sh"
