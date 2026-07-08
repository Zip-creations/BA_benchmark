#!/usr/bin/env bash
set -uo pipefail

REPORT_PATH="$(mktemp)"
trap 'rm -f "$REPORT_PATH"' EXIT

mapfile -t tests

if [[ "${#tests[@]}" -eq 0 ]]; then
    exit 0
fi

status=0

PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 PYTHONPATH="code" python3 -m pytest "${tests[@]}" --junit-xml="$REPORT_PATH" >&2 || status=$?

cat "$REPORT_PATH"
exit "$status"
