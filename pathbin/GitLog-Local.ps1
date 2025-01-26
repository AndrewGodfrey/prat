# .SYNOPSIS
# Shows git history under the current directory, for the last n commits or m months (default: 7 commits).
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
git log @optArgs --pretty="%C(auto)%as: %<(18,trunc)%an %h  %Cgreen%s%Creset" $Path

