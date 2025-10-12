# Returns a function that tells the caller which file paths to exclude from code coverage.
#
# I don't care about code coverage for files under "auto/".
# I tried using Pester's $Configuration.Run.ExcludePath, but that doesn't seem to affect the code coverage plugin.
# So I just let it put the data in coverage.xml, and filter it out in Get-CoverageReport.ps1.

return {
    param ($fileName) 
    $f = $fileName -replace '\\', '/'
    if ($f -match '/auto/') {
        return $true
    }
    return $false
}
