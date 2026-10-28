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
#
# Its own file, with no dependencies, so a caller outside PratBase can dot-source just this rather than import the
# module.
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
