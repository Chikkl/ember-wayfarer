#!/usr/bin/env bash
# Pre-commit checks from CLAUDE.md: GUT tests, gdlint and gdformat --check.
# Godot binary: the GODOT environment variable, otherwise `godot` from PATH.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"

echo "== import"
"$GODOT" --headless --path . --import 2>&1 | grep -E "ERROR|SCRIPT ERROR" && exit 1 || true

echo "== tests"
# GUT skips a test script that fails to parse and still reports success,
# so any SCRIPT ERROR in the test output fails the check.
tests_log="$(mktemp)"
trap 'rm -f "$tests_log"' EXIT
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gexit 2>&1 | tee "$tests_log"
if grep -q "SCRIPT ERROR" "$tests_log"; then
	echo "SCRIPT ERROR in the tests, see the output above"
	exit 1
fi

echo "== gdlint"
gdlint src tests

echo "== gdformat"
gdformat --check src tests
