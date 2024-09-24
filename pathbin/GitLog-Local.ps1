# .SYNOPSIS
# Shows git history under the current directory, for the last n months (default 3).
# Uses a concise one-line format, that still includes date and author information.
param ($Months=3)
git log --after="$Months months ago" --pretty="%C(auto)%as: %<(18,trunc)%an %h  %Cgreen%s%Creset" .

