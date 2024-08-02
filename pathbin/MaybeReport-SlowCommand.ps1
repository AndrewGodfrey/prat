# .SYNOPSIS
# If the user wasn't recently present (measured by mouse & keyboard input), send a notification that a slow command has
# completed - unless it's on a whitelist (especially for complex interactive commands, that wait for user input).
#
# Called by function reportOnSlowCommands. I put this in a script so I don't need to restart command prompts when I make
# changes to this.
param ($historyInfo, $lastCommandErrorStatus)

if (!(Get-Command 'Send-UserNotification' -ErrorAction SilentlyContinue)) { return }


$logFolder = "$home\prat\auto\log"
if (-not (Test-Path $logFolder)) { md $logFolder >$null}
function log($msg) {
    $now = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") # Note: Using local time instead of UTC
    $toLog = "$($now): $msg"
    echo $toLog | Out-file -Append -encoding UTF8 $logFolder\MaybeReport-SlowCommand.txt
}

log "Starting" # For debugging an unexpected multi-second slowdown that I sometimes see. I mean, it's probably in Send-UserNotification, but still.

$cmdArgs = $historyInfo.CommandLine.Split(" ")
$cmd = $cmdArgs[0] # Note: Doesn't handle spaces in the command name.
$cmd = $cmd -replace '^(.*)(\.(ps1|exe|com|bat|sh|bash))$', '$1' # Remove extension
$cmd = $cmd -replace '^.*[/\\]([^/\\]*)$', '$1'                  # Remove leading path

# I used to have more 'suppressing' cases, where I searched $cmd and $cmdArgs for various patterns to detect
# commands that are expected to wait for user input (e.g. 'more', 'gflags', 'hg help push').
# But thanks to Get-UserIdleTimeInSeconds, those aren't needed anymore. I'm leaving the logging in place
# for potential future complications.


# Note: Get-UserIdleTimeInSeconds takes quite a few seconds to load the first time.
# This is hidden from the user, because it's happening when a command has already been slow.
$userIdleTime = Get-UserIdleTimeInSeconds
if ($userIdleTime -lt 15) {
    log "suppressing: User is present: $userIdleTime seconds"
    return
}

$message = "'$cmd'"
$message += if (-not $lastCommandErrorStatus) { " failed" } else { " completed" }

$app = "prat"
log "Sending '$message' (app=$app), for command '$cmd'. Full command line: $($historyInfo.CommandLine)"
Send-UserNotification $message $app
log "Done"
