# A writer's own report of a write it has just made, for a layer above that needs to tell its session's writes from
# everyone else's. A file-system watcher sees that a file changed, not who changed it; this is the writer saying "that
# was me". Each layer may supply lib/agents/On-FileWritten_<layer>.ps1, which is run with -Path and should return
# quickly when nothing is tracking.

# $Path: the full path of the file written. A failing companion is reported without stopping the caller, whose write
# has already landed.
function Send-FileWrittenNotice([Parameter(Mandatory)][string] $Path, [string[]] $CompanionPaths = $null) {
    if ($null -eq $CompanionPaths) {
        $CompanionPaths = @(Resolve-PratLibFile 'lib/agents/On-FileWritten.ps1' -ListAll)
    }
    foreach ($companion in $CompanionPaths) {
        try {
            # Discarded, so a companion's output can't leak into the caller's return value.
            $null = & $companion -Path $Path
        } catch {
            Write-Error "file-written companion $companion failed for ${Path}: $_"
        }
    }
}
