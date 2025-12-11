#!/usr/bin/env bash
# Build script for better-claude-code
# Generates embedded content and runs bashly

set -euo pipefail

cd "$(dirname "$0")"

echo "Generating hook content..."
./scripts/generate-hook-content.sh

echo "Running bashly generate..."

# local modified version of bashly
/opt/homebrew/opt/ruby/bin/ruby -I ~/dev/bashly/lib ~/dev/bashly/bin/bashly generate

echo "Build complete: install.sh"
