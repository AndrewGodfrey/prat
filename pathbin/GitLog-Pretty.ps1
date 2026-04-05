# .SYNOPSIS
# 'Pretty' one-line git log
#
# Alias: glp
#
# Auto-behaviors:
#   --graph is added automatically when the range contains merge commits
#   Author column is omitted when all commits share the same author

$userWantsGraph = $args -contains '--graph'

$absoluteArg = $args | Where-Object { [System.IO.Path]::IsPathRooted($_) } | Select-Object -First 1
$repoRoot = if ($absoluteArg) { Resolve-GitRoot $absoluteArg } else { $null }
$gitC = if ($repoRoot) { @('-C', $repoRoot) } else { @() }

# Auto-detect merges (skip if user already asked for --graph)
$hasMerges = $false
if (-not $userWantsGraph) {
    $hasMerges = [bool] @(git @gitC log --merges --oneline @args 2>$null)
}

# Auto-detect uniform author
$authors = @(git @gitC log --pretty="%an" @args 2>$null | Select-Object -Unique)
$uniformAuthor = $authors.Count -le 1

$format = if ($uniformAuthor) {
    '%C(auto)%as: %h  %Cgreen%s%Creset'
} else {
    '%C(auto)%as: %<(18,trunc)%an %h  %Cgreen%s%Creset'
}

$extraFlags = if ((-not $userWantsGraph) -and $hasMerges) { @('--graph') } else { @() }

if ($uniformAuthor -and $authors.Count -eq 1) {
    Write-Host "Author: $($authors[0])"
}

git @gitC log "--pretty=$format" $extraFlags @args
