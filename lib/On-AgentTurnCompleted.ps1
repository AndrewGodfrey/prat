# .SYNOPSIS
# A 'Stop' hook function for agents, currently only designed for Claude Code.
#
# NOTE: Do not emit to stdout — Claude Code interprets hook stdout as instructions.
# All output is suppressed via | Out-Null on the main() call.
function Get-SessionName($hookData) {
    $transcriptPath = $hookData.transcript_path
    if (-not $transcriptPath -or -not (Test-Path $transcriptPath)) { return $null }

    $customTitle = $null
    $slug = $null
    foreach ($line in (Get-Content $transcriptPath)) {
        $entry = $line | ConvertFrom-Json -ErrorAction SilentlyContinue
        if (-not $entry) { continue }
        if ($entry.type -eq 'custom-title' -and $entry.customTitle) { $customTitle = $entry.customTitle }
        if (-not $slug -and $entry.slug) { $slug = $entry.slug }
    }
    return $(if ($customTitle) { $customTitle } else { $slug })
}

function main($hookData) {
    if (!(Get-Command 'Send-UserNotification' -ErrorAction SilentlyContinue)) { return }

    $userIdleTime = Get-UserIdleTimeInSeconds
    if ($userIdleTime -lt 45) { return }

    $name = Get-SessionName $hookData
    $message = if ($name) { "$($name): done" } else { 'agent turn completed' }
    Send-UserNotification $message 'prat'
}

if ($MyInvocation.InvocationName -ne '.') {
    $hookData = ([Console]::In.ReadToEnd()) | ConvertFrom-Json
    main $hookData | Out-Null
}
