#!/usr/bin/bash

PYTHONPATH_DIR="code"
REPORT_PATH="test/out/reportNew.xml"

PYTHONPATH="$PYTHONPATH_DIR" python3 -m pytest "$@" --junit-xml="$REPORT_PATH"

echo "REPORT_PATH=$REPORT_PATH"
cat "$REPORT_PATH"
