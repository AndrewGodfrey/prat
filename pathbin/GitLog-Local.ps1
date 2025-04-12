# .SYNOPSIS
# Shows recent git history for the current directory/given pathspec. 
#
# Alias: gll
#
# .NOTES
# Shows history for the last n commits or m months (default: 7 commits).
# Uses a concise one-line format, that still includes date and author information.
param ($Path=".", $n=$null, $Months=$null)

$optArgs = @()
if ($null -ne $Months) {
    if ($null -ne $n) {
        throw "Cannot specify both Months and n"
    }
    $optArgs += "--after=""$Months months ago""" 
} else {
    if ($null -eq $n) { $n = 7 }
    $optArgs += "--max-count=$n"
}
GitLog-Pretty @optArgs $Path

