# PostToolUse hook: fix-line-endings.ps1
#
# Automatically converts LF line endings to CRLF after Write or Edit tool calls,
# when the git repo requires it. Runs silently (no output on success).
#
# NOTE: Do not emit to stdout — Claude Code interprets hook stdout as instructions.
# All output is suppressed via | Out-Null on the main() call.
#
# When CRLF conversion is needed:
#
#   Case 1 — .gitattributes has an explicit eol=crlf rule for this file.
#             Detected via: git check-attr eol -- <file> → "eol: crlf"
#
#   Case 2 — core.autocrlf=true + core.safecrlf=true/warn in git config.
#             git refuses (or warns) when staging LF files because the round-trip
#             check fails: LF → stored as LF → checkout gives CRLF ≠ original LF.
#             Detected via: git config core.autocrlf + git config core.safecrlf.
#
# When CRLF conversion is NOT needed:
#
#   - Not inside a git repo → skip
#   - .gitattributes has explicit eol=lf for this file → skip (respect LF-only rule)
#   - core.autocrlf=true but safecrlf=false/unset → git handles silently, no need to convert
#   - core.autocrlf=input or false → no CRLF conversion in git pipeline, skip
#   - File has no LF bytes (already CRLF or binary) → skip conversion step
#   - macOS CR-only (\r) endings: modern macOS uses LF; old CR-only is a legacy
#     artifact git doesn't handle specially — not worth supporting.

function main($filePath) {
    if (-not $filePath -or -not (Test-Path $filePath -PathType Leaf)) { return }

    # Determine if CRLF conversion is needed before reading the file —
    # git config lookups are cheaper than reading file contents.

    # Must be inside a git repo
    $parentDir = Split-Path $filePath -Parent
    $repoRoot = git -C $parentDir rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $repoRoot) { return }

    # Check .gitattributes eol attribute for this file (Case 1)
    $attrOutput = git -C $repoRoot check-attr eol -- $filePath 2>$null
    if ($attrOutput -match ': eol: lf') { return }   # Explicitly LF — respect it
    $needsCrlf = $attrOutput -match ': eol: crlf'

    # Check git config for autocrlf + safecrlf (Case 2)
    if (-not $needsCrlf) {
        $autocrlf = git -C $repoRoot config core.autocrlf 2>$null
        if ($autocrlf -eq 'true') {
            $safecrlf = git -C $repoRoot config core.safecrlf 2>$null
            if ($safecrlf -eq 'true' -or $safecrlf -eq 'warn') {
                $needsCrlf = $true
            }
        }
    }

    if (-not $needsCrlf) { return }

    # Read file and convert: replace bare LF with CRLF
    # (idempotent — existing CRLF pairs are not doubled; skip binary files)
    $bytes = [System.IO.File]::ReadAllBytes($filePath)
    if ([Array]::IndexOf($bytes, [byte]10) -lt 0) { return }  # No LF bytes — nothing to do
    if ([Array]::IndexOf($bytes, [byte]0)  -ge 0) { return }  # Null bytes → binary, skip

    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    $converted = $text -replace '\r?\n', "`r`n"
    [System.IO.File]::WriteAllText($filePath, $converted, [System.Text.UTF8Encoding]::new($false))
}

if ($MyInvocation.InvocationName -ne '.') {
    $json = [Console]::In.ReadToEnd() | ConvertFrom-Json
    main $json.tool_input.file_path | Out-Null
}
