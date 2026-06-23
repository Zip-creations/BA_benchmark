#!/usr/bin/env bash
# base Output:
# test/test_identity.py::test_copy
# test/test_simple.py::test_add_item
# test/test_simple.py::test_removing_items
# test/test_simple.py::test_skipping

OUTPUT=$(PYTHONPATH=code python3 -m pytest --collect-only -q)

echo '<?xml version="1.0" encoding="utf-8"?>'
echo '<testsuite>'

while IFS= read -r line; do
    [[ "$line" != *"::"* ]] && continue

    file="${line%%::*}"   # test/test_simple.py
    test="${line##*::}"   # test_skipping

    module="${file%.py}"          # test/test_simple
    classname="${module//\//.}"   # test.test_simple

    echo "    <testcase classname=\"$classname\" name=\"$test\" qualifiedName=\"$line\"/>"
done <<< "$OUTPUT"

echo '</testsuite>'
