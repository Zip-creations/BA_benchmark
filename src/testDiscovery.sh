#!/usr/bin/env bash
set -uo pipefail

echo '<?xml version="1.0" encoding="utf-8"?>'
echo '<testsuite>'

PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 PYTHONPATH=code \
python3 -m pytest --collect-only -q \
    | while IFS= read -r line; do
        [[ "$line" != *"::"* ]] && continue

        file="${line%%::*}"
        test="${line##*::}"

        module="${file%.py}"
        classname="${module//\//.}"

        printf '    <testcase classname="%s" name="%s" qualifiedName="%s"/>\n' "$classname" "$test" "$line"
    done
echo '</testsuite>'
