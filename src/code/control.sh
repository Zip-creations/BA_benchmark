#!/usr/bin/env bash

test-all() {
    local commit="${1:-HEAD}"
    local discovery_script="./testDiscovery.sh"
    local execution_script="./testExecution.sh"

    local discovery
    if ! discovery="$("$discovery_script")"; then
        echo "testDiscovery failed" >&2
        return 1
    fi

    local input_file
    input_file="$(mktemp)"
    trap 'rm -f "$input_file"' RETURN

    {
        printf '%s\n' '<?xml version="1.0" encoding="utf-8"?>'
        printf '%s\n' '<testAuditorInput version="1.0">'

        printf '%s\n' '  <testDiscovery>'
        emit_cdata "$discovery"
        printf '\n%s\n' '  </testDiscovery>'

        printf '%s\n' '  <reports>'

        # ursprüngliche Input-Reports
        local note
        if note="$(git notes --ref="commits" show "$commit" 2>/dev/null)"; then
            if [[ -n "$note" ]]; then
                printf '%s\n' '    <report format="junit-xml" source="git-notes" ref="commits">'
                emit_cdata "$note"
                printf '\n%s\n' '    </report>'
            fi
        fi

        # bisherige testExecution-Reports aus refs/notes/testreports/*
        local full_ref
        while read -r full_ref; do
            local notes_ref="${full_ref#refs/notes/}"

            if note="$(git notes --ref="$notes_ref" show "$commit" 2>/dev/null)"; then
                if [[ -n "$note" ]]; then
                    printf '    <report format="junit-xml" source="git-notes" ref="%s">\n' "$notes_ref"
                    emit_cdata "$note"
                    printf '\n%s\n' '    </report>'
                fi
            fi
        done < <(git for-each-ref --format='%(refname)' refs/notes/testreports)

        printf '%s\n' '  </reports>'
        printf '%s\n' '</testAuditorInput>'
    } > "$input_file"

    local auditor_output
    if ! auditor_output="$(nix develop --command testAuditor < "$input_file")"; then
        echo "testAuditor failed" >&2
        return 1
    fi

    echo "testAuditor selected tests:" >&2
    if [[ -n "$auditor_output" ]]; then
        printf '%s\n' "$auditor_output" >&2
    else
        echo "(none)" >&2
    fi

    local execution_output
    local execution_status=0

    execution_output="$(
        printf '%s' "$auditor_output" | "$execution_script"
    )" || execution_status=$?

    local run_id
    run_id="$(date -u +%Y%m%dT%H%M%S)-$$"

    local notes_ref="testreports/$run_id"

    local report_file
    report_file="$(mktemp)"
    trap 'rm -f "$input_file" "$report_file"' RETURN

    printf '%s' "$execution_output" > "$report_file"

    if [[ ! -s "$report_file" ]]; then
        echo "testExecution produced no report; no git note written" >&2
        return "$execution_status"
    fi

    git notes --ref="$notes_ref" add -F "$report_file" "$commit"

    echo "wrote testExecution report to refs/notes/$notes_ref for $commit" >&2

    # Optional: finalen Report auch auf stdout von test-all ausgeben
    printf '%s\n' "$execution_output"

    return "$execution_status"
}

emit_cdata() {
    local content="$1"

    # Falls im Inhalt selbst "]]>" vorkommt, muss CDATA gesplittet werden.
    content=${content//]]>/]]]]><![CDATA[>}

    printf '<![CDATA[\n%s\n]]>' "$content"
}

show-notes() {
    for ref in $(git for-each-ref --format='%(refname)' refs/notes/testreports); do
        echo "===== $ref ====="
        git notes --ref="${ref#refs/notes/}" show HEAD 2>/dev/null || true
    done
}
