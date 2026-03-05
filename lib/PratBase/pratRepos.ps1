# Private wrapper
function Get-RepoProfileFiles {
    return @(Resolve-PratLibFile "repoProfile.ps1" -ListAll)
}

# Private helper: loads a list of repoProfile files and merges their repos and shortcuts.
#
# Takes an array of absolute file paths
# Returns @{ repos = @{...}; shortcuts = @{...} }, or $null if $Files is null/empty.
#
# Root resolution:
#   - section root: if relative: resolved against the file's directory
#   - per-repo root: if omitted, defaults to sectionRoot/id; if relative, resolved against sectionRoot
#   - shortcut paths: if relative: resolved against section root (or repo root for repo-level shortcuts)
#   - implicit shortcut <id> -> <repo.root> unless defined explicitly
#
# When the same shortcut name appears in multiple files, the first file wins.
function Get-PratRepoIndex {
    param([string[]] $Files)

    if ($null -eq $Files -or $Files.Count -eq 0) { return $null }

    function Add-Shortcuts($shortcuts, $base, [ref] $dest) {
        if ($null -eq $shortcuts) { return }
        foreach ($name in $shortcuts.Keys) {
            if ($dest.Value.ContainsKey($name)) { continue }  # first-one-wins
            $path = $shortcuts[$name]
            if (-not [System.IO.Path]::IsPathRooted($path)) { $path = "$base/$path" }
            $dest.Value[$name] = $path.TrimEnd('\', '/')
        }
    }

    $allRepos     = @{}
    $allShortcuts = @{}

    foreach ($file in $Files) {
        $fileItem    = Get-Item $file
        $profileData = . $file

        foreach ($sectionKey in $profileData.Keys) {
            $sectionRoot = if ([System.IO.Path]::IsPathRooted($sectionKey)) {
                $sectionKey
            } else {
                (Resolve-Path (Join-Path $fileItem.DirectoryName $sectionKey)).Path.Replace('\', '/')
            }
            $sectionRoot = $sectionRoot.TrimEnd('\', '/')
            $section     = $profileData[$sectionKey]

            if ($null -ne $section.repos) {
                foreach ($id in $section.repos.Keys) {
                    $repo    = $section.repos[$id]
                    $repo.id = $id

                    if ($null -eq $repo.root) {
                        $repo.root = "$sectionRoot/$id"
                    } elseif (-not [System.IO.Path]::IsPathRooted($repo.root)) {
                        $repo.root = "$sectionRoot/$($repo.root)"
                    }
                    $repo.root = ($repo.root).TrimEnd('\', '/')

                    # Resolve string command properties relative to the repoProfile file's directory
                    $fileDir = $fileItem.DirectoryName.Replace('\', '/')
                    foreach ($cmdName in @('build', 'test', 'deploy', 'prebuild')) {
                        if ($repo.ContainsKey($cmdName) -and ($repo[$cmdName] -is [string])) {
                            $cmdPath = $repo[$cmdName]
                            if (-not [System.IO.Path]::IsPathRooted($cmdPath)) {
                                $cmdPath = "$fileDir/$cmdPath"
                            }
                            $repo[$cmdName] = $cmdPath.Replace('\', '/')
                        }
                    }

                    $allRepos[$id] = $repo

                    Add-Shortcuts $repo.shortcuts $repo.root ([ref]$allShortcuts)
                }
            }

            Add-Shortcuts $section.shortcuts $sectionRoot ([ref]$allShortcuts)
        }
    }

    # Add implicit default shortcut per repo: <id> -> <repo.root>
    foreach ($id in $allRepos.Keys) {
        if (-not $allShortcuts.ContainsKey($id)) {
            $allShortcuts[$id] = $allRepos[$id].root
        }
    }

    return @{
        repos     = $allRepos
        shortcuts = $allShortcuts
    }
}

# .SYNOPSIS
# Given a location, finds which repo it's in.
# Searches repos registered in repoProfile_<devenv>.ps1 files from all registered dev environments.
#
# Other properties added to the returned object:
#   subdir: path of $Location relative to the repo root
function Get-PratRepo {
    [CmdletBinding()]
    param([string] $Location = $pwd)

    $Location = (Resolve-Path $Location).ProviderPath

    $files  = Get-RepoProfileFiles
    $index = Get-PratRepoIndex $files
    if ($null -eq $index) { return $null }

    [System.IO.DirectoryInfo] $locationDI = $Location
    $results = @()

    foreach ($repo in $index.repos.Values) {
        [System.IO.DirectoryInfo] $rootDI = $repo.root
        Write-Verbose "Get-PratRepo: Considering: $($repo.root)"
        if ($locationDI.FullName.StartsWith($rootDI.FullName, 'InvariantCultureIgnoreCase')) {
            Write-Verbose "Get-PratRepo: Match: $($repo.id)"
            $results += $repo
        }
    }

    Write-Verbose "Get-PratRepo: Found $($results.Length) matches"
    if ($results.Length -eq 0) { return $null }

    # If multiple repos match (e.g. a nested repo inside another), pick the most-specific one (longest root).
    # Throw if there's a tie.
    if ($results.Length -gt 1) {
        $results = @($results | Sort-Object { $_.root.Length } -Descending)
        $topLen  = $results[0].root.Length
        $results = @($results | Where-Object { $_.root.Length -eq $topLen })
        if ($results.Length -gt 1) { throw "Found too many matches" }
    }

    $item = $results[0]
    $item.subdir = Get-RelativePath $item.root $Location
    return $item
}

# .SYNOPSIS
# An extension of Get-PratRepo.
# Useful for codebases that have sub-projects.
#
# Uses the 'subprojects' property to decide which project we're in. (Picks the longest-prefix match).
# If no project is found, returns what Get-PratRepo returns.
function Get-PratProject {
    [CmdletBinding()]
    param([string] $Location = $pwd)

    $Location = (Resolve-Path $Location).ProviderPath
    $repo = Get-PratRepo $Location
    if ($null -eq $repo) { return $null }

    Write-Verbose "Search subprojects for $($repo.id)"
    [System.IO.DirectoryInfo] $locationDI = $Location

    $longestMatch = @{ key = $null; dest = "" }

    if ($null -ne $repo.subprojects) {
        foreach ($key in $repo.subprojects.Keys) {
            $subproject = $repo.subprojects[$key]
            $dest = $repo.root + "/" + $subproject.path
            Write-Verbose "Considering: $key"
            [System.IO.DirectoryInfo] $destDI = $dest
            Write-Verbose "Compare: '$($destDI.FullName)' vs '$($locationDI.FullName)'"
            if ($locationDI.FullName.StartsWith($destDI.FullName, 'InvariantCultureIgnoreCase')) {
                Write-Verbose "Found: $key"
                if ($dest.Length -gt ($longestMatch.dest.Length)) {
                    $longestMatch.key  = $key
                    $longestMatch.dest = $dest
                }
            }
        }
    }

    if ($null -eq $longestMatch.key) {
        return $repo
    }
    Write-Verbose "Found: $($longestMatch.key)"
    $matchedSubproject = $repo.subprojects[$longestMatch.key]
    $item = @{
        parentId = $repo.id
        id       = "$($repo.id)/$($longestMatch.key)"
        root     = $longestMatch.dest
        subdir   = $(Get-RelativePath $longestMatch.dest $Location)
    }

    if ($null -ne $matchedSubproject.workspace) {
        $item.workspace = $matchedSubproject.workspace
    }

    # Inherit any properties, that aren't already overridden, from $repo.
    #   e.g. it's useful for these properties: 'buildKind', 'workspace', 'cachedEnvDelta'
    foreach ($key in $repo.Keys) {
        if (!$item.ContainsKey($key)) {
            $item[$key] = $repo[$key]
        }
    }

    return $item
}

# .SYNOPSIS
# Searches all registered repoProfile files, for navigation shortcuts.
#
# With -ListAll:  Returns an ordered dictionary of all shortcuts.
# Otherwise:      Returns the absolute path for the given shortcut name, or $null if not found.
function Find-ProjectShortcut {
    [CmdletBinding()]
    param($Shortcut, [switch] $ListAll)

    $files       = Get-RepoProfileFiles
    $index      = Get-PratRepoIndex $files
    $allShortcuts = if ($null -ne $index) { $index.shortcuts } else { @{} }

    if ($ListAll) {
        $result = [ordered]@{}
        foreach ($key in $allShortcuts.Keys) { $result[$key] = $allShortcuts[$key] }
        return $result
    }
    if ($allShortcuts.Contains($Shortcut)) { return $allShortcuts[$Shortcut] }
    return $null
}
