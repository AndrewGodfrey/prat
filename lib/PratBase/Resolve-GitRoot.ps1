function Resolve-GitRoot {
    param([string] $FromPath = $null)
    $dir = if ($FromPath) {
        # Test-Path -PathType Container returns $false for non-existent paths, so non-existent
        # directories are misclassified as files and their parent is used instead. Callers should
        # pass existing paths.
        if (Test-Path -PathType Container $FromPath) { $FromPath } else { Split-Path $FromPath -Parent }
    } else { '.' }
    if (-not $dir) { $dir = '.' }
    (git -C $dir rev-parse --show-toplevel 2>$null) -replace '\\', '/'
}
