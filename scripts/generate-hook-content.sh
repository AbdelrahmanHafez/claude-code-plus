#!/usr/bin/env bash
# Generates hook_content.sh from assets/auto-approve-allowed-commands.sh
# This embeds the hook script content into a function for the installer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

SOURCE_FILE="$ROOT_DIR/assets/auto-approve-allowed-commands.sh"
OUTPUT_FILE="$ROOT_DIR/src/lib/hook_content.sh"

if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "Error: Source file not found: $SOURCE_FILE" >&2
  exit 1
fi

cat > "$OUTPUT_FILE" << 'HEADER'
# Auto-generated from assets/auto-approve-allowed-commands.sh - DO NOT EDIT DIRECTLY
# Edit assets/auto-approve-allowed-commands.sh instead, then run: ./build.sh

get_hook_script_content() {
  cat << 'HOOK_SCRIPT_EOF'
HEADER

cat "$SOURCE_FILE" >> "$OUTPUT_FILE"

cat >> "$OUTPUT_FILE" << 'FOOTER'

HOOK_SCRIPT_EOF
}
FOOTER

echo "Generated: $OUTPUT_FILE"
