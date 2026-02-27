#!/bin/bash
# Wrapper for Test-Prat.ps1 with identical parameter syntax.
# Enables a single Bash(Test-Prat.sh *) permission grant rather than ad-hoc pwsh invocations.
# Run from any directory — no 'cd' required.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

ARGS=()
while [[ $# -gt 0 ]]; do
    param="${1,,}"  # lowercase for case-insensitive matching
    case "$param" in
        -focus)                     ARGS+=("-Focus" "$2");                    shift 2 ;;
        -nocoverage)                ARGS+=("-NoCoverage");                    shift   ;;
        -debugging)                 ARGS+=("-Debugging");                     shift   ;;
        -includeintegrationtests)   ARGS+=("-IncludeIntegrationTests");       shift   ;;
        -reporoot)                  ARGS+=("-RepoRoot" "$2");                 shift 2 ;;
        -outputdir)                 ARGS+=("-OutputDir" "$2");                shift 2 ;;
        *) echo "Unknown parameter: $1" >&2; exit 1 ;;
    esac
done

cd "$REPO_ROOT" && pwsh -File "$SCRIPT_DIR/Test-Prat.ps1" "${ARGS[@]}" 2>&1
