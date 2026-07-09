#!/usr/bin/env bash
set -uo pipefail

REPORT_PATH="$(mktemp)"
ARGS_FILE="$(mktemp)"

trap 'rm -f "$REPORT_PATH" "$ARGS_FILE"' EXIT

mapfile -t tests

if [[ "${#tests[@]}" -eq 0 ]]; then
    exit 0
fi

printf '%s\n' "${tests[@]}" > "$ARGS_FILE"

status=0

PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 PYTHONPATH="code" python3 -m pytest "@$ARGS_FILE" --junit-xml="$REPORT_PATH" >&2 || status=$?

cat "$REPORT_PATH"
exit "$status"
