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

        # Inherit properties from parent node
        if ($null -ne $parentNode) {
            $node['parentId'] = $parentNode.id
            $node['repo']     = $repoNode
            foreach ($key in $parentNode.Keys) {
                if (($key -notin $structuralKeys) -and -not $node.ContainsKey($key)) {
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
        $file        = Resolve-JunctionInPath $file
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
# Searches repos registered in repoProfile_<devenv>.ps1 files from all registered dev environments.
# Returns the top-level repo only — use Get-PratProject to match subprojects.
#
# Other properties added to the returned object:
#   subdir: path of $Location relative to the repo root
function Get-PratRepo {
    [CmdletBinding()]
    param([string] $Location = $pwd)

    $Location = Resolve-JunctionInPath (Resolve-Path $Location).ProviderPath

    $index = Get-PratRepoIndex (Get-RepoProfileFiles)
    if ($null -eq $index) { return $null }

    $topLevel = @($index.repos.Values | Where-Object { -not $_.ContainsKey('parentId') })
    $item = Find-BestMatch $topLevel $Location
    if ($null -eq $item) { return $null }

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
function Get-PratProject {
    [CmdletBinding()]
    param([string] $Location = $pwd)

    $Location = Resolve-JunctionInPath (Resolve-Path $Location).ProviderPath

    $index = Get-PratRepoIndex (Get-RepoProfileFiles)
    if ($null -eq $index) { return $null }

    $item = Find-BestMatch $index.repos.Values $Location
    if ($null -eq $item) { return $null }

    $item.subdir = Get-RelativePath $item.root $Location
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
