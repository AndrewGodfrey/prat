# .SYNOPSIS
# 
# Functions for figuring out where we are relative to the 'main' development branch a.k.a. the 'forkpoint'.

# .SYNOPSIS
# Get the current forkpoint of the current branch (or detached HEAD state), relative to the given 'main' branch.
# The default of "origin/main" is good for repos that require pull requests.
#
# If you're isntead pushing to main, and especially if your own changes could invalidate the cache, then more work might be needed here.
# For one thing you probably want the local "main" instead of origin/main.
function Get-CurrentGitForkpoint($repoRoot, $mainBranch="origin/main") {
    $commitId = git -C $repoRoot merge-base --fork-point $mainBranch HEAD
    if ($null -eq $commitId) {
        # I find this happens if I'm not on a branch, but in detached head state
        # So then fall back to:
        $commitId = git -C $repoRoot merge-base $mainBranch HEAD
    }
    if ($null -eq $commitId) { throw "Internal error" }

    $authorDate = Get-Date (git -C $repoRoot log -1 --pretty='%aI' $commitId)

    return @{
        forkpointType = 'git'
        commitId = $commitId
        repoRoot = $repoRoot
        authorDate = $authorDate
    }
}

# .SYNOPSIS
# Decide on the relationship between two forkpoints. Exposed publicly in case it's needed for user-interface improvements.
# I'm not planning on using it externally yet.
#
# This is designed for deciding whether to invalidate/reuse a cache corresponding to the previous state.
# Recommended policy by return value:
#   equal:              Reuse the cache.
#   currentIsNewer:     Invalidate the cache.
#   currentIsOlder:     Depends on the situation. Reuse the cache if the 'newer' one is likely to be valid, or if it's hard/impossible to reliably go 'backwards'.
#   unrelated/complex:  Warn, and invalidate the cache
function Get-ForkpointRelationship($previousForkpoint, $currentForkpoint) {
    if ($currentForkpoint.forkpointType -ne $previousForkpoint.forkpointType) {
        throw "Internal error - comparing forkpoints of different types"
    }

    if ($currentForkpoint.repoRoot -ne $previousForkpoint.repoRoot) {
        throw "Internal error - comparing forkpoints from different repo roots"
    }

    if ($currentForkpoint.forkpointType -ne 'git') {
        throw "Internal error - unsupported forkpoint type '$($currentForkpoint.forkpointType)'"
    }

    if ($currentForkpoint.commitId -eq $previousForkpoint.commitId) {
        return 'equal'
    }
    $base = git -C $currentForkpoint.repoRoot merge-base $previousForkpoint.commitId $currentForkpoint.commitId
    if ($null -eq $base) {
        return 'unrelated'
    }
    if ($base -eq $currentForkpoint.commitId) {
        return 'currentIsOlder'
    }
    if ($base -eq $previousForkpoint.commitId) {
        return 'currentIsNewer'
    }
    return 'complex'
}

# .SYNOPSIS
# Decide if some data, cached against some forkpoint, is valid. (If invalid, it presumably needs to be updated.)
# An update is needed if the current forkpoint is newer, or if the cached forkpoint doesn't exist.
#
# .PARAMETER slopInterval
#  If specified, then we supress updates until the current forkpoint is at least this new.

# TODO:
# - implement slopinterval. Default it to 6.5 days? 0.9 days? Note in the caller that there's a default slop. Or default to 0? Seems wiser. Document that if you use slop,
#   you're saying that if you ever hit a dependency problem, you'll recognize it quickly and know to "pb -Force". While I'm here, isn't it weird that this is so pb-specific?
function Get-ForkpointCacheIsValid($fn, $currentForkpoint, $slopInterval = $null) {
    if (!($fn.EndsWith(".ps1"))) { throw 'Internal error: Cache filename needs to end in ".ps1"' }
    if ($null -ne $slopInterval) { throw "nyi" }

    if (!(Test-Path $fn)) { return $false }

    Write-Verbose "getCachedForkpoint: Load: $fn"
    $cachedForkpoint = . $fn

    $rel = Get-ForkpointRelationship $cachedForkpoint $currentForkpoint
    switch ($rel) {
        'equal'          { return $true }
        'currentIsNewer' { return $false }
        'currentIsOlder' { 
            Write-Warning "Current forkpoint is older than cached forkpoint. Reusing cache."
            return $true 
        }
        default {
            Write-Warning "Can't find common ancestor between cached forkpoint and current forkpoint"
            return $false 
        }
    }
}

# .SYNOPSIS
# Update metadata for a given cached item - i.e. marking it as valid against the given forkpoint.
# Future calls to 'Get-ForkpointCacheIsValid' against the same forkpoint, will return $true.
function Set-ForkpointCache($fn, $currentForkpoint) {
    if (!($fn.EndsWith(".ps1"))) { throw 'Internal error: Cache filename needs to end in ".ps1"' }
    $asText = ConvertTo-Expression $currentForkpoint

    New-FolderAndParents (Split-Path $fn -parent)
    Set-Content $asText -LiteralPath $fn
}
