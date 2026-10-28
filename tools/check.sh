#!/usr/bin/env bash
# Pre-commit checks from CLAUDE.md: GUT tests, gdlint and gdformat --check.
# Godot binary: the GODOT environment variable, otherwise `godot` from PATH.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"

echo "== import"
"$GODOT" --headless --path . --import 2>&1 | grep -E "ERROR|SCRIPT ERROR" && exit 1 || true

echo "== tests"
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit

echo "== gdlint"
gdlint src tests

echo "== gdformat"
gdformat --check src tests
