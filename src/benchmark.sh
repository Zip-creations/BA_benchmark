#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

BENCH_ROOT="${BENCH_ROOT:-$SCRIPT_DIR}"
CONTROL_SCRIPT="${CONTROL_SCRIPT:-$SCRIPT_DIR/control.sh}"
TEST_DISCOVERY_SCRIPT="${TEST_DISCOVERY_SCRIPT:-$SCRIPT_DIR/testDiscovery.sh}"
TEST_EXECUTION_SCRIPT="${TEST_EXECUTION_SCRIPT:-$SCRIPT_DIR/testExecution.sh}"

now_ns() {
    date +%s%N
}

duration_ms() {
    local start="$1"
    local end="$2"
    echo $(( (end - start) / 1000000 ))
}

count_report_tests() {
    local report="$1"

    if [[ ! -s "$report" ]]; then
        echo 0
        return
    fi

    python3 - "$report" <<'PY'
import sys
import xml.etree.ElementTree as ET

path = sys.argv[1]

try:
    root = ET.parse(path).getroot()
except Exception:
    print(0)
    raise SystemExit(0)

count = 0
for elem in root.iter():
    if elem.tag.split("}")[-1] == "testcase":
        count += 1

print(count)
PY
}

run_full_pytest() {
    local report="$1"
    local status=0

    PYTHONPATH="${PYTHONPATH:-code}" python3 -m pytest \
        --junit-xml="$report" \
        >&2 || status=$?

    return "$status"
}

validate_shared_scripts() {
    if [[ ! -f "$CONTROL_SCRIPT" ]]; then
        echo "control script not found: $CONTROL_SCRIPT" >&2
        return 1
    fi

    if [[ ! -f "$TEST_DISCOVERY_SCRIPT" ]]; then
        echo "testDiscovery script not found: $TEST_DISCOVERY_SCRIPT" >&2
        return 1
    fi

    if [[ ! -f "$TEST_EXECUTION_SCRIPT" ]]; then
        echo "testExecution script not found: $TEST_EXECUTION_SCRIPT" >&2
        return 1
    fi

    if ! command -v testAuditor >/dev/null 2>&1; then
        echo "testAuditor not found in PATH" >&2
        return 1
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        echo "python3 not found in PATH" >&2
        return 1
    fi
}

validate_benchmark_dir() {
    local bench_abs="$1"

    if [[ ! -d "$bench_abs" ]]; then
        echo "benchmark directory not found: $bench_abs" >&2
        return 1
    fi
}

run_benchmark_dir() {
    local bench_dir="$1"

    local bench_abs
    bench_abs="$(realpath "$bench_dir")"

    local bench_name
    bench_name="$(basename "$bench_abs")"

    local control_abs
    control_abs="$(realpath "$CONTROL_SCRIPT")"

    local discovery_abs
    discovery_abs="$(realpath "$TEST_DISCOVERY_SCRIPT")"

    local execution_abs
    execution_abs="$(realpath "$TEST_EXECUTION_SCRIPT")"

    validate_benchmark_dir "$bench_abs" || return 1

    local result_dir="$bench_abs/result"
    rm -rf "$result_dir"
    mkdir -p "$result_dir"

    local log_file="$result_dir/benchmark.log"

    local tmp_dir
    tmp_dir="$(mktemp -d)"

    local full_report="$tmp_dir/full-report.xml"
    local full_stderr="$tmp_dir/full.stderr"

    local optimized_report="$tmp_dir/optimized-report.xml"
    local optimized_stderr="$tmp_dir/optimized.stderr"

    {
        echo "benchmark=$bench_name"
        echo "benchmark_abs=$bench_abs"
        echo "timestamp=$(date -Iseconds)"
        echo
    } > "$log_file"

    (
        cd "$bench_abs" || exit 1

        source "$control_abs"

        # Override:
        # Use shared testDiscovery.sh from src instead of ./testDiscovery.sh.
        ta-from-discovery() {
            local commit="${1:-HEAD}"
            local discovery

            if ! discovery="$(bash "$discovery_abs")"; then
                echo "testDiscovery failed" >&2
                return 1
            fi

            printf '%s' "$discovery" | ta-from-wrapper "$commit"
        }

        # Override:
        # Use archive/*.xml instead of git notes as historical reports.
        ta-from-wrapper() {
            local commit="${1:-HEAD}"
            local discovery
            discovery="$(cat)"

            local input_file
            input_file="$(mktemp)"
            trap 'rm -f "$input_file"' RETURN

            {
                printf '%s\n' '<?xml version="1.0" encoding="utf-8"?>'
                printf '%s\n' '<testAuditorInput version="1.0">'

                printf '%s\n' '  <testDiscovery>'
                printf '%s' "$discovery" | emit_cdata
                printf '\n%s\n' '  </testDiscovery>'

                printf '%s\n' '  <reports>'

                if [[ -d archive ]]; then
                    while IFS= read -r report; do
                        printf '%s\n' '    <report format="junit-xml">'
                        emit_cdata < "$report"
                        printf '\n%s\n' '    </report>'
                    done < <(find archive -type f -name '*.xml' | sort)
                fi

                printf '%s\n' '  </reports>'
                printf '%s\n' '</testAuditorInput>'
            } > "$input_file"

            cat "$input_file" | ta-from-auditor "$commit"
        }

        # Override:
        # Use shared testExecution.sh from src instead of ./testExecution.sh.
        ta-from-execution() {
            local commit="${1:-HEAD}"
            local execution_output
            local execution_status=0

            execution_output="$(bash "$execution_abs")" || execution_status=$?

            if [[ -z "$execution_output" ]]; then
                echo "testExecution produced no report" >&2
                return "$execution_status"
            fi

            printf '%s' "$execution_output" | ta-write-note "$commit"
            return "$execution_status"
        }

        # Override:
        # Do not write git notes during benchmarks.
        ta-write-note() {
            cat
        }

        local start
        local end

        local full_status
        local full_duration_ms
        local full_tests

        local optimized_status
        local optimized_duration_ms
        local optimized_tests

        local relative_runtime

        echo "== full run ==" >> "$log_file"
        echo "description=direct pytest run without testDiscovery and without testAuditor" >> "$log_file"

        start="$(now_ns)"
        run_full_pytest "$full_report" 2> "$full_stderr"
        full_status=$?
        end="$(now_ns)"

        full_duration_ms="$(duration_ms "$start" "$end")"
        full_tests="$(count_report_tests "$full_report")"

        echo "full_status=$full_status" >> "$log_file"
        echo "full_duration_ms=$full_duration_ms" >> "$log_file"
        echo "full_tests=$full_tests" >> "$log_file"
        echo "-- full stderr --" >> "$log_file"
        cat "$full_stderr" >> "$log_file"
        echo >> "$log_file"

        echo "== optimized run ==" >> "$log_file"
        echo "description=shared testDiscovery + archive reports + testAuditor + shared selected testExecution" >> "$log_file"

        start="$(now_ns)"
        test-all > "$optimized_report" 2> "$optimized_stderr"
        optimized_status=$?
        end="$(now_ns)"

        optimized_duration_ms="$(duration_ms "$start" "$end")"
        optimized_tests="$(count_report_tests "$optimized_report")"

        echo "optimized_status=$optimized_status" >> "$log_file"
        echo "optimized_total_duration_ms=$optimized_duration_ms" >> "$log_file"
        echo "optimized_tests=$optimized_tests" >> "$log_file"
        echo "-- optimized stderr --" >> "$log_file"
        cat "$optimized_stderr" >> "$log_file"
        echo >> "$log_file"

        echo "== summary ==" >> "$log_file"
        echo "full_tests=$full_tests" >> "$log_file"
        echo "full_duration_ms=$full_duration_ms" >> "$log_file"
        echo "full_status=$full_status" >> "$log_file"
        echo "optimized_tests=$optimized_tests" >> "$log_file"
        echo "optimized_total_duration_ms=$optimized_duration_ms" >> "$log_file"
        echo "optimized_status=$optimized_status" >> "$log_file"

        relative_runtime="$(
            awk -v full="$full_duration_ms" -v opt="$optimized_duration_ms" \
                'BEGIN {
                    if (full > 0) {
                        printf "%.2f", opt / full
                    } else {
                        print "n/a"
                    }
                }'
        )"

        echo "relative_runtime=$relative_runtime" >> "$log_file"

        if [[ "$full_status" -ne 0 || "$optimized_status" -ne 0 ]]; then
            echo "benchmark_completed_with_test_failures=true" >> "$log_file"
        else
            echo "benchmark_completed_with_test_failures=false" >> "$log_file"
        fi
    )

    local benchmark_status=$?

    rm -rf "$tmp_dir"

    if [[ "$benchmark_status" -eq 0 ]]; then
        echo "wrote $log_file" >&2
    else
        echo "benchmark failed for $bench_name; see $log_file" >&2
    fi

    return "$benchmark_status"
}

main() {
    local found=0
    local failed=0

    validate_shared_scripts || return 1

    for bench_dir in "$BENCH_ROOT"/bench_*; do
        [[ -d "$bench_dir" ]] || continue

        found=1

        if ! run_benchmark_dir "$bench_dir"; then
            failed=1
        fi
    done

    if [[ "$found" -eq 0 ]]; then
        echo "No bench_* directories found in $BENCH_ROOT." >&2
        return 1
    fi

    return "$failed"
}

main "$@"
