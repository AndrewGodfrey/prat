# .SYNOPSIS
# Runs Pester with various code-coverage options
#
# .PARAMETER CoverageType
# None:      No code coverage (runs faster)
# Standard:  Produces CoverageGutter output. Coverage percentage is measured against the entire repo.
# Subset:    Like Standard, but coverage percentage is measured against the code under the current directory only.
[CmdletBinding()]
param (
    [switch] $Coverage = $true,
    $PathToTest = ".",
    $RepoRoot = (Resolve-Path "$PSScriptRoot\.."),
    [ValidateSet("CoverageGutters", "JaCoCo")] [string] $CoverageFormat = "CoverageGutters"
)

function moveCoverageFile($tempFile, $coverageDest = "$RepoRoot/auto/coverage.xml") {
    # We send the coverage data to a temp file and then move it.
    # Why: Otherwise, Pester 5.5.0 puts relative path names in coverage.xml for any .ps1 files it finds under auto/.
    #      Which causes trouble e.g. in Get-CoverageReport.ps1.

    # TODO: Extract this into a function which create the 'auto' directory and also checks if .gitignore is set up to ignore it.
    $dir = Split-Path $coverageDest
    if (!(Test-Path $dir)) {
        New-Item $dir -ItemType Directory | Out-Null
    }
    try {
        Move-Item $tempFile $coverageDest -ErrorAction Stop -Force
    } catch {
        Write-Warning "Failed to move coverage file '$tempFile' to destination '$coverageDest': $_"
    }
}

$savedVerbosePreference = $VerbosePreference
if ($VerbosePreference -ne "SilentlyContinue") { $VerbosePreference = "SilentlyContinue" }
    Import-Module Pester
$VerbosePreference = $savedVerbosePreference

$Configuration = [PesterConfiguration]::Default
$Configuration.Run.Path = $PathToTest
if ($VerbosePreference -ne "SilentlyContinue") {
    # This is handy for pinpointing some unwanted output - e.g. an uncaught Write-Warning.
    $Configuration.Output.Verbosity = "Detailed"
}

if ($Coverage) {
    $tempFile = [IO.Path]::GetTempFileName()
    $Configuration.CodeCoverage.OutputPath = $tempFile
    $Configuration.CodeCoverage.Enabled = [bool] $true
    $Configuration.CodeCoverage.OutputFormat = $CoverageFormat
    $Configuration.CodeCoverage.Path = & "$PSScriptRoot/../lib/Get-CoverageScope" -PathToTest $PathToTest -RepoRoot $RepoRoot
    $Configuration.CodeCoverage.CoveragePercentTarget = & (Resolve-PratLibFile "lib/Get-CoveragePercentTarget.ps1")
}

Invoke-PesterAsJob -Configuration $Configuration

if ($Coverage) {
    if (Test-Path $tempFile) {
        moveCoverageFile $tempFile
    }
}