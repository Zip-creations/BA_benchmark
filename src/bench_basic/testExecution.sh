#!/usr/bin/env bash
set -uo pipefail

REPORT_PATH="test/out/reportNew.xml"
mkdir -p "$(dirname "$REPORT_PATH")"
mapfile -t tests

echo "testExecution received ${#tests[@]} tests" >&2
status=0

if [[ "${#tests[@]}" -eq 0 ]]; then
    exit 0
else
    PYTHONPATH="code" python3 -m pytest "${tests[@]}" --junit-xml="$REPORT_PATH" >&2 || status=$?
fi

cat "$REPORT_PATH"
exit "$status"
