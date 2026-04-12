# Expands a leading '~' to the home directory. Call this before [System.IO.Path]::IsPathRooted(),
# which doesn't understand '~'. Works on paths that don't exist yet; use instead of Resolve-Path /
# Convert-Path when existence cannot be guaranteed.
function Expand-TildePath([string] $Path) {
    if ($Path -like '~*') {
        return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    }
    return $Path
}
