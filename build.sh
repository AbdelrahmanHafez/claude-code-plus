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

echo "Build complete: install.sh"
