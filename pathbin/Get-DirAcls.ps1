<#
.SYNOPSIS
Summarizes directory ACLs under a given path, grouping dirs that share the same ACL pattern.
#>
param($rootPath = ".")

function main($rootPath) {
    $root = (Resolve-Path $rootPath).Path.TrimEnd('\') + '\'
    $results = [ordered] @{}
    foreach ($path in (Get-ChildItem -Recurse -Directory -FollowSymlink $rootPath)) {
        $acl = fixup (icacls $path.FullName)
        $rel = $path.FullName.Substring($root.Length)
        if ($null -eq $results[$acl]) { $results[$acl] = @() }
        $results[$acl] += $rel
    }

    dumpResults $results $root
}


function dumpPathList($paths) {
    function decorate($arr) {
        return @($arr | Foreach-Object { "$_\" } )
    }
    if ($paths.Length -le 3) { 
        return (decorate $paths) -Join ", "
    }

    return ((decorate $paths[0..2]) -Join ", ") + ", and $($paths.Length - 3) others"
}

function dumpResults($results, $root) {
    "ACLs for dirs under $($root): `n"
    foreach ($acl in $results.Keys) {
        [string] $paths = (dumpPathList $results[$acl])
        "$($paths):`n$acl`n`n"
    }
}

function fixup($strings) {
    if (!($strings[1] -match "^( +)")) { return ($strings -join "; ") }
    $indent = $matches[1].Length
    $result = @()
    foreach ($line in $strings) {
        if ($line -match 'Successfully processed') { continue }
        if ($indent -ge $line.Length) { continue } else {
            $result += $line.Substring($indent)
        }
    }
    return ($result -join "; ")
}

main $rootPath