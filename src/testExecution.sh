#!/usr/bin/env bash
set -uo pipefail

REPORT_PATH="$(mktemp)"
trap 'rm -f "$REPORT_PATH"' EXIT

mapfile -t tests

echo "testExecution received ${#tests[@]} tests" >&2
status=0

if [[ "${#tests[@]}" -eq 0 ]]; then
    exit 0
fi

PYTHONPATH="code" python3 -m pytest "${tests[@]}" --junit-xml="$REPORT_PATH" >&2 || status=$?
cat "$REPORT_PATH"
exit "$status"
