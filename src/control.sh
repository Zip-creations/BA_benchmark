#!/usr/bin/env bash

# run full pipeline
test-all() {
    local commit="${1:-HEAD}"
    ta-from-discovery "$commit"
}

# run only the tests passed as arguments
test-pick() {
    if [[ "$#" -eq 0 ]]; then
        echo "Usage: test-pick testname..." >&2
        return 1
    fi
    printf '%s\n' "$@" | ta-from-execution HEAD
}

# run test discovery and forward its output
ta-from-discovery() {
    local commit="${1:-HEAD}"
    local discovery_script="./testDiscovery.sh"
    local discovery

    if ! discovery="$("$discovery_script")"; then
        echo "testDiscovery failed" >&2
        return 1
    fi
    printf '%s' "$discovery" | ta-from-wrapper "$commit"
}

# build testAuditorInput XML from testDiscovery and notes
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
        # embed current discovery result
        printf '%s\n' '  <testDiscovery>'
        printf '%s' "$discovery" | emit_cdata
        printf '\n%s\n' '  </testDiscovery>'
        printf '%s\n' '  <reports>'

        local note
        # add testDiscovery to XML
        if note="$(git notes --ref="commits" show "$commit" 2>/dev/null)"; then
            if [[ -n "$note" ]]; then
                printf '%s\n' '    <report format="junit-xml">'
                printf '%s' "$note" | emit_cdata
                printf '\n%s\n' '    </report>'
            fi
        fi

        # add previous execution reports to XML
        local full_ref
        while read -r full_ref; do
            local notes_ref="${full_ref#refs/notes/}"
            if note="$(git notes --ref="$notes_ref" show "$commit" 2>/dev/null)"; then
                if [[ -n "$note" ]]; then
                    printf '    <report format="junit-xml">\n' "$notes_ref"
                    printf '%s' "$note" | emit_cdata
                    printf '\n%s\n' '    </report>'
                fi
            fi
        done < <(git for-each-ref --format='%(refname)' refs/notes/testreports)

        printf '%s\n' '  </reports>'
        printf '%s\n' '</testAuditorInput>'
    } > "$input_file"
    cat "$input_file" | ta-from-auditor "$commit"
}

# run testAuditor and forward selected tests
ta-from-auditor() {
    local commit="${1:-HEAD}"
    local auditor_output

    if ! auditor_output="$(testAuditor)"; then
        echo "testAuditor failed" >&2
        return 1
    fi

    echo "testAuditor picked the following tests for execution:" >&2
    # if [[ -n "$auditor_output" ]]; then
    printf '%s\n' "$auditor_output" >&2
    # else
    #     echo "(none)" >&2
    # fi
    # keep stdin clean if no tests were selected
    printf '%s' "$auditor_output" | ta-from-execution "$commit"
}

# run selected tests and forward the produced report
ta-from-execution() {
    local commit="${1:-HEAD}"
    local execution_script="./testExecution.sh"
    local execution_output
    local execution_status=0

    execution_output="$("$execution_script")" || execution_status=$?
    if [[ -z "$execution_output" ]]; then
        echo "testExecution produced no report; no note written" >&2
        return "$execution_status"
    fi
    printf '%s' "$execution_output" | ta-write-note "$commit"
    return "$execution_status"
}

# store a report as a new testreports note
ta-write-note() {
    local commit="${1:-HEAD}"

    local report_file
    report_file="$(mktemp)"
    trap 'rm -f "$report_file"' RETURN

    cat > "$report_file"

    if [[ ! -s "$report_file" ]]; then
        echo "empty report; no note written" >&2
        return 0
    fi

    local run_id
    run_id="$(date -u +%Y%m%dT%H%M%S)-$$-$RANDOM"

    local notes_ref="testreports/$run_id"

    git notes --ref="$notes_ref" add -F "$report_file" "$commit"
    echo "wrote testExecution report to refs/notes/$notes_ref for $commit" >&2
    cat "$report_file"
}

# wrap stdin into CDATA
emit_cdata() {
    local content
    content="$(cat)"

    # escape CDATA terminator
    content=${content//]]>/]]]]><![CDATA[>}
    printf '<![CDATA[\n%s\n]]>' "$content"
}

# Show testreports notes for a commit
show-notes() {
    local commit="${1:-HEAD}"

    for ref in $(git for-each-ref --format='%(refname)' refs/notes/testreports); do
        local short_ref="${ref#refs/notes/}"
        local note
        if note="$(git notes --ref="$short_ref" show "$commit" 2>/dev/null)"; then
            echo "===== $ref ====="
            printf '%s\n' "$note"
            echo
        fi
    done
}
