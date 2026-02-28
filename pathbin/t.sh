#!/bin/bash
# Wrapper for Test-Codebase.ps1 — exercises the full codebase test chain.
# Enables a single Bash(t.sh *) permission grant rather than ad-hoc pwsh invocations.
# Run from any directory — no 'cd' required; use -RepoRoot to specify which codebase.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CD_TO="$REPO_ROOT"

ARGS=()
while [[ $# -gt 0 ]]; do
    param="${1,,}"  # lowercase for case-insensitive matching
    case "$param" in
        -focus)                     ARGS+=("-Focus" "$2");                    shift 2 ;;
        -nocoverage)                ARGS+=("-NoCoverage");                    shift   ;;
        -debugging)                 ARGS+=("-Debugging");                     shift   ;;
        -includeintegrationtests)   ARGS+=("-IncludeIntegrationTests");       shift   ;;
        -reporoot)                  ARGS+=("-RepoRoot" "$2"); CD_TO="$2";     shift 2 ;;
        -outputdir)                 ARGS+=("-OutputDir" "$2");                shift 2 ;;
        *) echo "Unknown parameter: $1" >&2; exit 1 ;;
    esac
done

cd "$CD_TO" && pwsh -File "$SCRIPT_DIR/Test-Codebase.ps1" "${ARGS[@]}" 2>&1
