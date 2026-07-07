#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

RUNS="${RUNS:-10}"
BENCH_ROOT="${BENCH_ROOT:-$SCRIPT_DIR}"
BENCHMARK_SCRIPT="${BENCHMARK_SCRIPT:-$SCRIPT_DIR/benchmark.sh}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

trim() {
    awk '{$1=$1; print}'
}

extract_first_value() {
    local key="$1"
    local file="$2"

    awk -F= -v key="$key" '
        function trim(s) {
            gsub(/^[ \t\r\n]+/, "", s)
            gsub(/[ \t\r\n]+$/, "", s)
            return s
        }

        $1 == key {
            print trim($2)
            exit
        }
    ' "$file"
}

extract_last_value() {
    local key="$1"
    local file="$2"

    awk -F= -v key="$key" '
        function trim(s) {
            gsub(/^[ \t\r\n]+/, "", s)
            gsub(/[ \t\r\n]+$/, "", s)
            return s
        }

        $1 == key {
            value = trim($2)
        }

        END {
            if (value != "") print value
        }
    ' "$file"
}

append_metric() {
    local data_file="$1"
    local run="$2"
    local key="$3"
    local value="$4"

    if [[ -n "$value" ]]; then
        printf '%s\t%s\t%s\n' "$run" "$key" "$value" >> "$data_file"
    fi
}

append_run_result() {
    local run="$1"
    local bench_dir="$2"

    local bench_name
    bench_name="$(basename "$bench_dir")"

    local log_file="$bench_dir/result/benchmark.log"
    local saved_dir="$TMP_DIR/$bench_name"
    local saved_log="$saved_dir/benchmark_${run}.log"
    local data_file="$saved_dir/metrics.tsv"

    mkdir -p "$saved_dir"

    if [[ ! -f "$log_file" ]]; then
        echo "missing benchmark.log for $bench_name in run $run" >&2
        return 0
    fi

    cp "$log_file" "$saved_log"

    local full_tests
    local full_total_ms
    local full_test_ms
    local full_overhead_ms
    local full_status

    local optimized_tests
    local optimized_total_ms
    local optimized_test_ms
    local optimized_overhead_ms
    local optimized_status

    local relation
    local terminated_with_error

    full_tests="$(extract_first_value "full run total executed tests" "$log_file")"
    full_total_ms="$(extract_first_value "full run total duration in ms" "$log_file")"
    full_status="$(extract_first_value "full run exit status" "$log_file")"

    optimized_tests="$(extract_first_value "optimized run total executed tests" "$log_file")"
    optimized_total_ms="$(extract_first_value "optimized run total duration in ms" "$log_file")"
    optimized_status="$(extract_first_value "optimized run exit status" "$log_file")"

    relation="$(extract_first_value "optimized to full run relation" "$log_file")"
    terminated_with_error="$(extract_first_value "benchmark terminated with error" "$log_file")"

    # In deiner aktuellen benchmark.log kommt diese Metrik zweimal vor:
    # 1. full run
    # 2. optimized run
    full_test_ms="$(extract_first_value "pytest test duration in ms" "$log_file")"
    optimized_test_ms="$(extract_last_value "pytest test duration in ms" "$log_file")"

    if [[ -n "$full_total_ms" && -n "$full_test_ms" ]]; then
        full_overhead_ms=$(( full_total_ms - full_test_ms ))
    else
        full_overhead_ms=""
    fi

    if [[ -n "$optimized_total_ms" && -n "$optimized_test_ms" ]]; then
        optimized_overhead_ms=$(( optimized_total_ms - optimized_test_ms ))
    else
        optimized_overhead_ms=""
    fi

    append_metric "$data_file" "$run" "full run total executed tests" "$full_tests"
    append_metric "$data_file" "$run" "full run total duration in ms" "$full_total_ms"
    append_metric "$data_file" "$run" "full run test duration in ms" "$full_test_ms"
    append_metric "$data_file" "$run" "full run overhead in ms" "$full_overhead_ms"
    append_metric "$data_file" "$run" "full run exit status" "$full_status"

    append_metric "$data_file" "$run" "optimized run total executed tests" "$optimized_tests"
    append_metric "$data_file" "$run" "optimized run total duration in ms" "$optimized_total_ms"
    append_metric "$data_file" "$run" "optimized run test duration in ms" "$optimized_test_ms"
    append_metric "$data_file" "$run" "optimized run overhead in ms" "$optimized_overhead_ms"
    append_metric "$data_file" "$run" "optimized run exit status" "$optimized_status"

    append_metric "$data_file" "$run" "optimized to full run relation" "$relation"
    append_metric "$data_file" "$run" "benchmark terminated with error" "$terminated_with_error"
}

average_metric() {
    local data_file="$1"
    local key="$2"

    awk -F'\t' -v key="$key" '
        $2 == key && $3 ~ /^-?[0-9]+([.][0-9]+)?$/ {
            sum += $3
            count += 1
        }

        END {
            if (count > 0) {
                printf "%.6f", sum / count
            } else {
                printf "n/a"
            }
        }
    ' "$data_file"
}

count_metric_value() {
    local data_file="$1"
    local key="$2"
    local expected="$3"

    awk -F'\t' -v key="$key" -v expected="$expected" '
        $2 == key && $3 == expected {
            count += 1
        }

        END {
            print count + 0
        }
    ' "$data_file"
}

write_average_log() {
    local bench_dir="$1"

    local bench_name
    bench_name="$(basename "$bench_dir")"

    local saved_dir="$TMP_DIR/$bench_name"
    local data_file="$saved_dir/metrics.tsv"
    local result_dir="$bench_dir/result"
    local average_log="$result_dir/average.log"

    if [[ ! -f "$data_file" ]]; then
        echo "no collected metrics for $bench_name" >&2
        return 0
    fi

    mkdir -p "$result_dir"

    # benchmark.sh erzeugt pro Lauf benchmark.log und löscht result/.
    # Hier werden am Ende nur die nummerierten Logs zurückgelegt.
    rm -f "$result_dir/benchmark.log"
    cp "$saved_dir"/benchmark_*.log "$result_dir/"

    local runs_recorded
    runs_recorded="$(awk -F'\t' '{print $1}' "$data_file" | sort -n | uniq | wc -l)"

    {
        echo "benchmark=$bench_name"
        echo "runs requested=$RUNS"
        echo "runs recorded=$runs_recorded"
        echo "timestamp=$(date -Iseconds)"
        echo

        echo "== averages =="
        echo "full run total executed tests average=$(average_metric "$data_file" "full run total executed tests")"
        echo "full run total duration in ms average=$(average_metric "$data_file" "full run total duration in ms")"
        echo "full run test duration in ms average=$(average_metric "$data_file" "full run test duration in ms")"
        echo "full run overhead in ms average=$(average_metric "$data_file" "full run overhead in ms")"

        echo
        echo "optimized run total executed tests average=$(average_metric "$data_file" "optimized run total executed tests")"
        echo "optimized run total duration in ms average=$(average_metric "$data_file" "optimized run total duration in ms")"
        echo "optimized run test duration in ms average=$(average_metric "$data_file" "optimized run test duration in ms")"
        echo "optimized run overhead in ms average=$(average_metric "$data_file" "optimized run overhead in ms")"
        echo "optimized to full run relation average=$(average_metric "$data_file" "optimized to full run relation")"

        echo
        echo "== status =="
        echo "full run failed runs=$(awk -F'\t' '$2 == "full run exit status" && $3 != "0" { count++ } END { print count + 0 }' "$data_file")"
        echo "optimized run failed runs=$(awk -F'\t' '$2 == "optimized run exit status" && $3 != "0" { count++ } END { print count + 0 }' "$data_file")"
        echo "benchmark terminated with error runs=$(count_metric_value "$data_file" "benchmark terminated with error" "true")"

    } > "$average_log"

    echo "wrote $average_log" >&2
}

main() {
    if [[ ! -f "$BENCHMARK_SCRIPT" ]]; then
        echo "benchmark script not found: $BENCHMARK_SCRIPT" >&2
        return 1
    fi

    for run in $(seq 1 "$RUNS"); do
        echo "===== benchmark run $run/$RUNS =====" >&2

        if ! BENCH_ROOT="$BENCH_ROOT" "$BENCHMARK_SCRIPT"; then
            echo "benchmark.sh returned non-zero in run $run" >&2
        fi

        for bench_dir in "$BENCH_ROOT"/bench_*; do
            [[ -d "$bench_dir" ]] || continue
            append_run_result "$run" "$bench_dir"
        done
    done

    for bench_dir in "$BENCH_ROOT"/bench_*; do
        [[ -d "$bench_dir" ]] || continue
        write_average_log "$bench_dir"
    done
}

main "$@"
