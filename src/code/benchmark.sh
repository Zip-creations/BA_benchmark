#!/usr/bin/env bash
set -uo pipefail

source ./control.sh

BENCH_DIR="benchmark/out/$(date -u +%Y%m%dT%H%M%S)"
mkdir -p "$BENCH_DIR"

FULL_REPORT="$BENCH_DIR/full-report.xml"
FULL_LOG="$BENCH_DIR/full.log"
FULL_META="$BENCH_DIR/full.meta"

OPT_REPORT="$BENCH_DIR/optimized-report.xml"
OPT_LOG="$BENCH_DIR/optimized.log"
OPT_META="$BENCH_DIR/optimized.meta"

SUMMARY="$BENCH_DIR/summary.tsv"

# Run a command and write duration/status to a meta file.
measure() {
    local meta_file="$1"
    shift

    local start end status duration_ms

    start="$(date +%s%N)"
    "$@"
    status=$?
    end="$(date +%s%N)"

    duration_ms=$(( (end - start) / 1000000 ))

    printf '%s\t%s\n' "$duration_ms" "$status" > "$meta_file"
    return 0
}

# Baseline: run all tests directly.
run-full() {
    PYTHONPATH="code" python3 -m pytest \
        --junit-xml="$FULL_REPORT"
}

# Count tests from JUnit XML.
count-tests() {
    local report="$1"

    if [[ ! -s "$report" ]]; then
        echo 0
        return
    fi

    grep -o '<testsuite[ >][^>]*tests="[0-9][0-9]*"' "$report" \
        | sed -E 's/.*tests="([0-9]+)".*/\1/' \
        | awk '{sum += $1} END {print sum + 0}'
}

echo "Running full test suite..." >&2
measure "$FULL_META" run-full > "$FULL_LOG" 2>&1

echo "Running optimized testAuditor pipeline..." >&2
measure "$OPT_META" test-all > "$OPT_REPORT" 2> "$OPT_LOG"

read -r full_ms full_status < "$FULL_META"
read -r opt_ms opt_status < "$OPT_META"

full_tests="$(count-tests "$FULL_REPORT")"
opt_tests="$(count-tests "$OPT_REPORT")"

speedup="$(
    awk -v full="$full_ms" -v opt="$opt_ms" \
        'BEGIN { if (opt > 0) printf "%.2f", full / opt; else print "n/a" }'
)"

{
    printf 'variant\ttests\tduration_ms\tstatus\n'
    printf 'full\t%s\t%s\t%s\n' "$full_tests" "$full_ms" "$full_status"
    printf 'optimized\t%s\t%s\t%s\n' "$opt_tests" "$opt_ms" "$opt_status"
    printf '\n'
    printf 'speedup\t%s\n' "$speedup"
} > "$SUMMARY"

cat "$SUMMARY"

echo >&2
echo "Benchmark files written to: $BENCH_DIR" >&2
