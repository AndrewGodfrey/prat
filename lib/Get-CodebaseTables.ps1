# .SYNOPSIS
# Given a directory, loads all cbTable.*.ps1 files directly in that directory.
# Returns @{ repos = @{...}; shortcuts = @{...} } or $null if no cbTable files were found.
#
# cbTable file schema:
#   root      (optional) - file-level base path; defaults to the cbTable file's parent directory
#   repos     - hashtable, id -> @{ root?, shortcuts?, cachedEnvDelta?, workspace?, buildKind?, subprojects?, testDirFromDevDir? }
#   shortcuts - hashtable, name -> relative-or-absolute path
#
# Root resolution:
#   - file-level root defaults to the cbTable file's parent directory
#   - per-repo root defaults to fileRoot/id
#   - each repo also gets an implicit shortcut <id> -> <repo.root> unless shortcuts already has that name
#   - relative shortcut paths are resolved against the file-level root (or the repo root for repo-level shortcuts)

[CmdletBinding()]
param ([string] $Location = $pwd)

if (-not (Test-Path $Location -ErrorAction SilentlyContinue)) { return $null }
$Location = (Resolve-Path $Location).Path

$cbFiles = @(Get-ChildItem (Join-Path $Location "cbTable.*.ps1") -ErrorAction SilentlyContinue)
if ($cbFiles.Count -eq 0) { return $null }

function Add-Shortcuts($shortcuts, $base, [ref] $dest) {
    if ($null -eq $shortcuts) { return }
    foreach ($name in $shortcuts.Keys) {
        $path = $shortcuts[$name]
        if (-not [System.IO.Path]::IsPathRooted($path)) { $path = "$base/$path" }
        $dest.Value[$name] = $path.TrimEnd('\', '/')
    }
}

$allRepos     = @{}
$allShortcuts = @{}

foreach ($cbFile in $cbFiles) {
    Write-Verbose "Get-CodebaseTables: Load: $cbFile"
    $cbData = . $cbFile.FullName
    Write-Verbose "Get-CodebaseTables: Loaded: $cbFile"

    $fileRoot = if ($null -ne $cbData.root) { $cbData.root } else { $cbFile.DirectoryName }

    if ($null -ne $cbData.repos) {
        foreach ($id in $cbData.repos.Keys) {
            $repo    = $cbData.repos[$id]
            $repo.id = $id

            if ($null -eq $repo.root) { $repo.root = "$fileRoot/$id" }
            $repo.root = ($repo.root).TrimEnd('\', '/')

            Write-Verbose "Get-CodebaseTables: repo $id -> $($repo.root)"
            $allRepos[$id] = $repo

            Add-Shortcuts $repo.shortcuts $repo.root ([ref]$allShortcuts)
        }
    }

    Add-Shortcuts $cbData.shortcuts $fileRoot ([ref]$allShortcuts)
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
