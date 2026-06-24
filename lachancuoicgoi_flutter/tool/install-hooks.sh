#!/usr/bin/env bash
# Copy pre-commit hook template to .git/hooks/pre-commit and make it executable.
# Run once after cloning.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cp "$ROOT/lachancuoicgoi_flutter/tool/pre-commit.template" "$ROOT/.git/hooks/pre-commit"
chmod +x "$ROOT/.git/hooks/pre-commit"
echo "✅ Pre-commit hook installed successfully."
