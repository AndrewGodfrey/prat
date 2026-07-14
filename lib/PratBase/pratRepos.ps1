# Import-Scriptblock: dot-sources a .ps1 data file and returns the result with all
# scriptblock module associations removed.
#
# WHY THIS IS NEEDED:
#   To avoid infinite recursion.
#
#   PowerShell attaches a module to each scriptblock at compile time, based on the session
#   state active during compilation. When . (dot-source) runs inside a module function, every
#   scriptblock compiled from the dot-sourced file inherits that module's association.
#
#   So: Without this, our scriptblocks would have Module=PratBase. When one of those
#       later calls 'using module PratBase', GetExportedTypeDefinitions() scans PratBase's scriptblock
#       for type definitions, finds our scriptblock, re-enters, and recurses infinitely (stack overflow).
#
# HOW THE FIX WORKS:
#   [scriptblock]::Create(str) is a .NET static method. It compiles PowerShell source text
#   outside the session-state tree entirely, producing a scriptblock with Module=$null. The
#   Module property is stored on the object and preserved on later invocation. Strip-Scriptblocks
#   recursively walks the returned data to recompile every scriptblock it finds.
#
#   Other attempts that didn't work: 
#   dot-sourcing via an external script or a [scriptblock]::Create() loader did not
#   help. PowerShell propagates the calling module's session state to any code invoked from within that module's
#   call stack. The only escape found so far is [scriptblock]::Create(), which sidesteps the
#   session-state tree by going to the .NET layer.
#
# LIMITATIONS:
#   - Closures: only source text is preserved. Variables captured via .GetNewClosure() are
#     lost. Workaround: use [scriptblock]::Create() in the data file, baking variable values
#     into source text via string concatenation instead of capturing them.
#   - PSCustomObject values are not walked — only hashtables and arrays.
function Import-Scriptblock([string]$File) {
    return Strip-Scriptblocks (. $File)
}

function Strip-Scriptblocks($data) {
    if ($data -is [scriptblock]) { return [scriptblock]::Create($data.ToString()) }
    if ($data -is [hashtable]) {
        $result = @{}
        foreach ($key in $data.Keys) { $result[$key] = Strip-Scriptblocks $data[$key] }
        return $result
    }
    if ($data -is [array]) { return @($data | ForEach-Object { Strip-Scriptblocks $_ }) }
    return $data
}

# Private wrapper
function Get-RepoProfileFiles {
    return @(Resolve-PratLibFile "codebaseProfile.ps1" -ListAll)
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
#
# Junction restriction: all repos registered in a codebaseProfile file must be in the same NTFS
# junction island as the locations passed to Get-PratRepo/Get-PratProject. Cross-island references
# (e.g. a profile accessed via junction A registering a root accessible via junction B) silently
# return null — "Unknown project" when t/d are run from that island.
function Get-PratRepoIndex {
    param([string[]] $Files)

    if ($null -eq $Files -or $Files.Count -eq 0) { return $null }

    function Add-Shortcuts($shortcuts, $base, [ref] $dest, $currentFile, [ref] $sources) {
        if ($null -eq $shortcuts) { return }
        foreach ($name in $shortcuts.Keys) {
            if ($dest.Value.ContainsKey($name)) {
                if ($sources.Value[$name] -eq $currentFile) {
                    throw "Duplicate shortcut '$name' defined multiple times within the same repoProfile file '$currentFile'."
                }
                continue  # first-file-wins across files
            }
            $path = $shortcuts[$name]
            if (-not [System.IO.Path]::IsPathRooted($path)) { $path = "$base/$path" }
            $dest.Value[$name] = $path.TrimEnd('\', '/')
            $sources.Value[$name] = $currentFile
        }
    }

    function Register-Node($nodeId, $nodeDef, $absoluteRoot, $fileDir, $parentNode, $repoNode, $currentFile) {
        # Build the node, copying all non-structural properties from the definition.
        $structuralKeys = @('root', 'path', 'subprojects', 'shortcuts')
        $node = @{ id = $nodeId; root = $absoluteRoot }
        foreach ($key in $nodeDef.Keys) {
            if ($key -notin $structuralKeys) { $node[$key] = $nodeDef[$key] }
        }

        # Inherit properties from parent node. `test` is excluded: it's scoped to the parent's own
        # root, so inheriting it onto a child is never meaningful — the child declares its own or
        # gets one auto-detected (see Resolve-ProjectTestScript).
        if ($null -ne $parentNode) {
            $node['parentId'] = $parentNode.id
            $node['repo']     = $repoNode
            foreach ($key in $parentNode.Keys) {
                if (($key -notin $structuralKeys) -and ($key -ne 'test') -and -not $node.ContainsKey($key)) {
                    $node[$key] = $parentNode[$key]
                }
            }
        }

        # Resolve string command properties relative to the repoProfile file's directory.
        # Scriptblock stripping is handled by Import-Scriptblock before we get here.
        foreach ($cmdName in @('build', 'test', 'deploy', 'prebuild')) {
            if ($node.ContainsKey($cmdName)) {
                if ($node[$cmdName] -is [string]) {
                    $cmdPath = $node[$cmdName]
                    if (-not [System.IO.Path]::IsPathRooted($cmdPath)) { $cmdPath = "$fileDir/$cmdPath" }
                    $node[$cmdName] = $cmdPath.Replace('\', '/')
                }
            } else {
                # Auto-discover: lib/projects/<id>/<cmd>_<id>.ps1
                $autoPath = "$fileDir/lib/projects/$nodeId/${cmdName}_$nodeId.ps1"
                if (Test-Path $autoPath) { $node[$cmdName] = $autoPath }
            }
        }

        $allRepos[$nodeId] = $node
        Add-Shortcuts $nodeDef.shortcuts $absoluteRoot ([ref]$allShortcuts) $currentFile ([ref]$allShortcutSources)

        # Recurse into subprojects.
        $childRepoNode = if ($null -eq $repoNode) { $node } else { $repoNode }
        if ($null -ne $nodeDef.subprojects) {
            foreach ($subKey in $nodeDef.subprojects.Keys) {
                $subDef  = $nodeDef.subprojects[$subKey]
                $subRoot = "$absoluteRoot/$($subDef.path)".TrimEnd('/', '\')
                Register-Node "$nodeId/$subKey" $subDef $subRoot $fileDir $node $childRepoNode $currentFile
            }
        }
    }

    $allRepos          = @{}
    $allShortcuts      = @{}
    $allShortcutSources = @{}

    foreach ($file in $Files) {
        $fileItem    = Get-Item $file
        $fileDir     = $fileItem.DirectoryName.Replace('\', '/')
        $profileData = Import-Scriptblock $file

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
                    $repoDef = $section.repos[$id]
                    $root    = if ($null -eq $repoDef.root) {
                        "$sectionRoot/$id"
                    } elseif (-not [System.IO.Path]::IsPathRooted($repoDef.root)) {
                        "$sectionRoot/$($repoDef.root)"
                    } else {
                        $repoDef.root
                    }
                    $root = $root.TrimEnd('\', '/')
                    Register-Node $id $repoDef $root $fileDir $null $null $file
                }
            }

            Add-Shortcuts $section.shortcuts $sectionRoot ([ref]$allShortcuts) $file ([ref]$allShortcutSources)
        }
    }

    # Add implicit default shortcut per node: <id> -> <node.root>
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

# Resolve-JunctionInPath: if $path itself or any ancestor is a Windows NTFS junction,
# returns the path with that junction replaced by its target. Otherwise returns $path.
#
# Junction islands: two paths that refer to the same file via different junctions are in
# different "islands" — string comparison treats them as unrelated even though they resolve
# to the same real location. Calling this function on both sides of a comparison bridges
# islands by reducing all paths to their real targets.
#
# Prat's project system deliberately does NOT call this: repos are registered and locations
# are looked up in whatever island the caller naturally inhabits, so same-island comparisons
# just work. Cross-island references silently return null (see Get-PratRepoIndex).
#
# Use this explicitly when you need to compare paths that may arrive from different islands,
# or when a downstream tool requires a real (non-junction) path.
function Resolve-JunctionInPath([string]$path) {
    $suffix  = [System.Collections.Generic.List[string]]::new()
    $current = $path
    while ($true) {
        $item = Get-Item -LiteralPath $current -ErrorAction SilentlyContinue
        if ($item -and $item.LinkType -eq 'Junction') {
            $base = $item.Target
            if ($suffix.Count -eq 0) { return $base }
            return "$base\$($suffix -join '\')"
        }
        $parent = [System.IO.Path]::GetDirectoryName($current)
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) { break }
        $suffix.Insert(0, [System.IO.Path]::GetFileName($current))
        $current = $parent
    }
    return $path
}

# Private: finds the most-specific node in $nodes whose root is a prefix of $Location.
# Returns $null if no match. Throws if two nodes tie at the same root length.
function Find-BestMatch($nodes, [string] $Location) {
    [System.IO.DirectoryInfo] $locationDI = $Location
    $results = @()
    foreach ($node in $nodes) {
        [System.IO.DirectoryInfo] $rootDI = $node.root
        if ($locationDI.FullName.StartsWith($rootDI.FullName + '\', 'InvariantCultureIgnoreCase') -or
            $locationDI.FullName.Equals($rootDI.FullName, 'InvariantCultureIgnoreCase')) {
            $results += $node
        }
    }
    if ($results.Length -eq 0) { return $null }
    if ($results.Length -gt 1) {
        $results = @($results | Sort-Object { $_.root.Length } -Descending)
        $topLen  = $results[0].root.Length
        $results = @($results | Where-Object { $_.root.Length -eq $topLen })
        if ($results.Length -gt 1) { throw "Found too many matches" }
    }
    return $results[0]
}

# .SYNOPSIS
# Given a location, finds which top-level repo it's in.
# Searches repos registered in codebaseProfile_<devenv>.ps1 files from all registered dev environments.
# Returns the top-level repo only — use Get-PratProject to match subprojects.
#
# Other properties added to the returned object:
#   subdir: path of $Location relative to the repo root
function Get-PratRepo {
    [CmdletBinding()]
    param([string] $Location = $pwd)

    $Location = (Resolve-Path $Location).ProviderPath

    $index = Get-PratRepoIndex (Get-RepoProfileFiles)
    if ($null -eq $index) { return $null }

    $gitRoot = Resolve-GitRoot $Location
    if (-not $gitRoot) { return $null }

    $topLevel = @($index.repos.Values | Where-Object { -not $_.ContainsKey('parentId') })
    $matches = @($topLevel | Where-Object { ($_.root -replace '\\', '/') -ieq $gitRoot })
    if ($matches.Count -eq 0) { return $null }
    if ($matches.Count -gt 1) { throw "Found too many matches" }
    $item = $matches[0]

    $item.subdir = Get-RelativePath $item.root $Location
    return $item
}

# .SYNOPSIS
# Given a location, finds the most-specific project (repo or subproject) it's in.
# Subprojects are registered in the flat index by Get-PratRepoIndex, so this is a
# simple longest-prefix match over all nodes at any depth.
#
# Other properties added to the returned object:
#   subdir: path of $Location relative to the project root
#
# A $null return is ambiguous between "genuinely unregistered" and "junction-island mismatch"
# (see Get-PratRepoIndex's junction-restriction comment). On a miss, this checks
# Find-JunctionIslandMismatch and Write-Warnings if that's the actual cause, so a caller relying on
# the $null return (e.g. a script probing whether it's in a project) isn't broken by the warning.
function Get-PratProject {
    [CmdletBinding()]
    param([string] $Location = $pwd)

    $Location = (Resolve-Path $Location).ProviderPath

    $index = Get-PratRepoIndex (Get-RepoProfileFiles)
    if ($null -eq $index) { return $null }

    $item = Find-BestMatch $index.repos.Values $Location
    if ($null -eq $item) {
        $mismatch = Find-JunctionIslandMismatch -Location $Location
        if ($null -ne $mismatch) {
            Write-Warning ("'$Location' matches project '$($mismatch.id)' (root: $($mismatch.root)) " +
                "only after resolving NTFS junctions - this is a junction-island mismatch, not an " +
                "unregistered project. Pass a path in the same junction island the project registry " +
                "was built from.")
        }
        return $null
    }

    $item.subdir = Get-RelativePath $item.root $Location
    return $item
}

# .SYNOPSIS
# Namespaced OutputDir for $Project's test run: <repo root>/auto/testRuns/<project id's last
# segment>, so nested projects don't collide. Repo root is $Project.repo.root for a subproject,
# else `git rev-parse --show-toplevel` (a top-level project with no parent).
function Get-ProjectTestOutputDir($Project) {
    $repoRoot = if ($Project.repo) {
        $Project.repo.root -replace '\\', '/'
    } else {
        $gitRoot = git -C $Project.root rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -ne 0) { throw "Not in a git repository: $($Project.root)" }
        $gitRoot -replace '\\', '/'
    }
    $outputLeaf = $Project.id -replace '.*/', ''
    "$repoRoot/auto/testRuns/$outputLeaf"
}

# .SYNOPSIS
# Test framework(s) detected under $ProjectRoot: 'pytest' (pyproject.toml, or a top-level
# test_*.py/conftest.py) and/or 'dotnet' (a *.Tests.csproj anywhere under the root). Returns an
# array in stable order @('pytest', 'dotnet'); @() if neither is found. A project can have both.
function Get-DetectedTestFrameworks($ProjectRoot) {
    $frameworks = @()

    $hasPytestMarker = (Test-Path (Join-Path $ProjectRoot 'pyproject.toml')) -or
                        (Test-Path (Join-Path $ProjectRoot 'conftest.py')) -or
                        (Get-ChildItem -LiteralPath $ProjectRoot -Filter 'test_*.py' -ErrorAction SilentlyContinue)
    if ($hasPytestMarker) { $frameworks += 'pytest' }

    $testCsproj = Get-ChildItem -LiteralPath $ProjectRoot -Recurse -Filter '*.Tests.csproj' -ErrorAction SilentlyContinue
    if ($testCsproj) { $frameworks += 'dotnet' }

    $frameworks
}

# .SYNOPSIS
# Effective `test` for $Project: its own declaration if set (Register-Node never inherits `test`
# onto children — see its own comment), else the generic dispatcher (Invoke-DetectedProjectTest.ps1)
# if a framework is detected, else $null.
function Resolve-ProjectTestScript($Project) {
    if ($Project.test) { return $Project.test }
    if ((Get-DetectedTestFrameworks $Project.root).Count -gt 0) {
        return (Resolve-Path "$PSScriptRoot/../Invoke-DetectedProjectTest.ps1").Path -replace '\\', '/'
    }
    return $null
}

# .SYNOPSIS
# Every registered project under $RootPath (subproject, or a sibling repo merely nested under it)
# with an effective `test` (see Resolve-ProjectTestScript) — for aggregating a repo's run across
# pytest/dotnet/Pester sub-targets. Each result's `.test` is always the effective script.
# `excludeFromAggregation` opts a node out, e.g. a dispatch-mechanics fixture whose own result
# shouldn't fold into a parent's summary.
function Get-PratTestTargetsUnder {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string] $RootPath)

    $normalizedRoot = ($RootPath -replace '\\', '/').TrimEnd('/')
    $index = Get-PratRepoIndex (Get-RepoProfileFiles)
    if ($null -eq $index) { return @() }

    @($index.repos.Values | Where-Object {
        -not $_.excludeFromAggregation -and
        ($_.root -replace '\\', '/').StartsWith($normalizedRoot + '/', 'InvariantCultureIgnoreCase')
    } | ForEach-Object {
        $resolvedTest = Resolve-ProjectTestScript $_
        if ($resolvedTest) {
            $clone = $_.Clone()
            $clone.test = $resolvedTest
            $clone
        }
    })
}

# .SYNOPSIS
# Top-level repo roots that declare a `grantAgentAccess` value ('rw' | 'read') on their
# codebaseProfile entry, grouped by that value. Single source of truth for "which repos an agent
# may touch" — callers (e.g. sandbox ACL grants, the agent-permission hook's policy data)
# derive their path lists from this instead of each hand-listing repos independently.
#
# .OUTPUTS
# @{ rw = [string[]]; read = [string[]] } — absolute repo root paths (registry's forward-slash
# form), each array sorted for deterministic output.
function Get-PratAgentGrantedPaths {
    [CmdletBinding()]
    param()

    $index = Get-PratRepoIndex (Get-RepoProfileFiles)
    $rw   = @()
    $read = @()
    if ($null -ne $index) {
        foreach ($repo in $index.repos.Values) {
            if ($repo.ContainsKey('parentId')) { continue }
            if ($repo['grantAgentAccess'] -eq 'rw') { $rw += $repo.root }
            elseif ($repo['grantAgentAccess'] -eq 'read') { $read += $repo.root }
        }
    }
    return @{ rw = @($rw | Sort-Object); read = @($read | Sort-Object) }
}

# .SYNOPSIS
# Diagnostic for a Get-PratProject miss: checks whether $Location would match a registered
# project once NTFS junctions are resolved on both sides. A match here means the caller passed
# a path in a different "junction island" than the one the registry was built from (see the
# Junction islands note above Get-PratRepoIndex) — the project exists, but the plain string-prefix
# match doesn't bridge junctions. Returns the would-be match, or $null if truly unregistered.
function Find-JunctionIslandMismatch {
    [CmdletBinding()]
    param([string] $Location = $pwd)

    $Location = (Resolve-Path $Location).ProviderPath

    $index = Get-PratRepoIndex (Get-RepoProfileFiles)
    if ($null -eq $index) { return $null }

    $resolvedLocation = Resolve-JunctionInPath $Location
    $resolvedNodes = $index.repos.Values | ForEach-Object {
        $clone = $_.Clone()
        $clone.root = Resolve-JunctionInPath $_.root
        $clone
    }

    return Find-BestMatch $resolvedNodes $resolvedLocation
}

# .SYNOPSIS
# Searches all registered repoProfile files, for navigation shortcuts.
#
# With -ListAll:  Returns an ordered dictionary of all shortcuts.
# Otherwise:      Returns the absolute path for the given shortcut name, or $null if not found.
function Find-ProjectShortcut {
    [CmdletBinding()]
    param($Shortcut, [switch] $ListAll)

    $files      = Get-RepoProfileFiles
    $index      = Get-PratRepoIndex $files
    $allShortcuts = if ($null -ne $index) { $index.shortcuts } else { @{} }

    if ($ListAll) {
        $result = [ordered]@{}
        foreach ($key in ($allShortcuts.Keys | Sort-Object)) { $result[$key] = $allShortcuts[$key] }
        return $result
    }
    if ($allShortcuts.Contains($Shortcut)) { return $allShortcuts[$Shortcut] }

    $foundPartialMatches = @()
    foreach ($k in $allShortcuts.Keys) {
        if ($k.EndsWith("/$Shortcut", 'InvariantCultureIgnoreCase')) { 
            $foundPartialMatches += $k
        } 
    }
    if ($foundPartialMatches.Count -gt 0) {
        if ($foundPartialMatches.Count -gt 1) {
            # We can't use declaration order to tie-break these, because the data structure uses unordered hashtables.
            throw "Found multiple partial matches for '$Shortcut': $($foundPartialMatches -join ', '))"
        }
        return $allShortcuts[$foundPartialMatches[0]]
    }
    
    return $null
}
