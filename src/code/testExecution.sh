#!/usr/bin/bash

# in case the testing framework requires a file to write the result into,
# the result of the run that is initialized by the tool should be placed in file other than the original result
REPORT_PATH="test/out/reportNew.xml"  

PYTHONPATH="code" python3 -m pytest "$@" --junit-xml="$REPORT_PATH"

echo "REPORT_PATH=$REPORT_PATH"
cat "$REPORT_PATH"
