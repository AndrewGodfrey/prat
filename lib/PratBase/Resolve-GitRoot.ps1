function Resolve-GitRoot {
    param([string] $FromPath = $null)
    $dir = if ($FromPath) {
        # Test-Path -PathType Container returns $false for non-existent paths, so non-existent
        # directories are misclassified as files and their parent is used instead. Callers should
        # pass existing paths.
        if (Test-Path -PathType Container $FromPath) { $FromPath } else { Split-Path $FromPath -Parent }
    } else { '.' }
    if (-not $dir) { $dir = '.' }
    # git -C can't read a literal '~'; expand it while staying in the caller's junction island.
    $dir = Expand-TildePath $dir

    # --show-toplevel resolves junctions (it computes an absolute real path), which pulls the
    # result out of the caller's junction island. --show-cdup returns a relative offset instead
    # ("../../" or ""), so joining it onto $dir keeps the result in the caller's path space.
    $cdup = (git -C $dir rev-parse --show-cdup 2>$null)
    if ($LASTEXITCODE -ne 0) { return $null }

    $absDir = [System.IO.Path]::GetFullPath((Convert-Path $dir))
    $root = [System.IO.Path]::GetFullPath((Join-Path $absDir $cdup.Trim()))
    ($root -replace '\\', '/').TrimEnd('/')
}
