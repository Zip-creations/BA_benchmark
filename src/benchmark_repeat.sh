#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

RUNS="${RUNS:-10}"
BENCH_ROOT="${BENCH_ROOT:-$SCRIPT_DIR}"
BENCHMARK_SCRIPT="${BENCHMARK_SCRIPT:-$SCRIPT_DIR/benchmark.sh}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

METRICS=(
    "full run total executed tests"
    "full run total duration in ms"
    "full run pytest duration in ms"
    "full run other overhead in ms"

    "optimized run total executed tests"
    "optimized run total duration in ms"
    "optimized run testDiscovery duration in ms"
    "optimized run testAuditor duration in ms"
    "optimized run testExecution duration in ms"
    "optimized run other overhead in ms"

    "optimized to full run relation"
)

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

    local metric
    local value

    for metric in "${METRICS[@]}"; do
        value="$(extract_first_value "$metric" "$log_file")"
        append_metric "$data_file" "$run" "$metric" "$value"
    done

    local full_status
    local optimized_status
    local terminated_with_error

    full_status="$(extract_first_value "full run exit status" "$log_file")"
    optimized_status="$(extract_first_value "optimized run exit status" "$log_file")"
    terminated_with_error="$(extract_first_value "benchmark terminated with error" "$log_file")"

    append_metric "$data_file" "$run" "full run exit status" "$full_status"
    append_metric "$data_file" "$run" "optimized run exit status" "$optimized_status"
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
                printf "%.4f", sum / count
            } else {
                printf "n/a"
            }
        }
    ' "$data_file"
}

count_nonzero_status() {
    local data_file="$1"
    local key="$2"

    awk -F'\t' -v key="$key" '
        $2 == key && $3 != "0" {
            count += 1
        }

        END {
            print count + 0
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

copy_numbered_logs_back() {
    local saved_dir="$1"
    local result_dir="$2"

    rm -f "$result_dir"/benchmark_*.log
    rm -f "$result_dir/benchmark.log"

    local log
    for log in "$saved_dir"/benchmark_*.log; do
        [[ -f "$log" ]] || continue
        cp "$log" "$result_dir/"
    done
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
    copy_numbered_logs_back "$saved_dir" "$result_dir"

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
        echo "full run pytest duration in ms average=$(average_metric "$data_file" "full run pytest duration in ms")"
        echo "full run other overhead in ms average=$(average_metric "$data_file" "full run other overhead in ms")"

        echo
        echo "optimized run total executed tests average=$(average_metric "$data_file" "optimized run total executed tests")"
        echo "optimized run total duration in ms average=$(average_metric "$data_file" "optimized run total duration in ms")"
        echo "optimized run testDiscovery duration in ms average=$(average_metric "$data_file" "optimized run testDiscovery duration in ms")"
        echo "optimized run testAuditor duration in ms average=$(average_metric "$data_file" "optimized run testAuditor duration in ms")"
        echo "optimized run testExecution duration in ms average=$(average_metric "$data_file" "optimized run testExecution duration in ms")"
        echo "optimized run other overhead in ms average=$(average_metric "$data_file" "optimized run other overhead in ms")"
        echo "optimized to full run relation average=$(average_metric "$data_file" "optimized to full run relation")"

        echo
        echo "== status =="
        echo "full run failed runs=$(count_nonzero_status "$data_file" "full run exit status")"
        echo "optimized run failed runs=$(count_nonzero_status "$data_file" "optimized run exit status")"
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

        local bench_dir
        for bench_dir in "$BENCH_ROOT"/bench_*; do
            [[ -d "$bench_dir" ]] || continue
            append_run_result "$run" "$bench_dir"
        done
    done

    local bench_dir
    for bench_dir in "$BENCH_ROOT"/bench_*; do
        [[ -d "$bench_dir" ]] || continue
        write_average_log "$bench_dir"
    done
}

main "$@"
