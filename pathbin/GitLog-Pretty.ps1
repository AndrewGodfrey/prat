# .SYNOPSIS
# 'Pretty' one-line git log
#
# Alias: glp
#
# Auto-behaviors:
#   --graph is added automatically when the range contains merge commits
#   Author column is omitted when all commits share the same author

$userWantsGraph = $args -contains '--graph'

# Auto-detect merges (skip if user already asked for --graph)
$hasMerges = $false
if (-not $userWantsGraph) {
    $hasMerges = [bool] @(git log --merges --oneline @args 2>$null)
}

# Auto-detect uniform author
$authors = @(git log --pretty="%an" @args 2>$null | Select-Object -Unique)
$uniformAuthor = $authors.Count -le 1

$format = if ($uniformAuthor) {
    '%C(auto)%as: %h  %Cgreen%s%Creset'
} else {
    '%C(auto)%as: %<(18,trunc)%an %h  %Cgreen%s%Creset'
}

$extraFlags = if ((-not $userWantsGraph) -and $hasMerges) { @('--graph') } else { @() }

git log "--pretty=$format" $extraFlags @args
