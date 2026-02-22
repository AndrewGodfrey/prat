# .SYNOPSIS
# Runs Pester with various code-coverage options
#
# .PARAMETER CoverageType
# None:      No code coverage (runs faster)
# Standard:  Produces CoverageGutter output. Coverage percentage is measured against the entire repo.
# Subset:    Like Standard, but coverage percentage is measured against the code under the current directory only.
[CmdletBinding()]
param (
    [ValidateSet("None", "Standard", "Subset")] [string] $CoverageType = "Standard",
    $PathToTest = ".",
    $RepoRoot = (Resolve-Path "$PSScriptRoot\.."),
    [ValidateSet("CoverageGutters", "JaCoCo")] [string] $CoverageFormat = "CoverageGutters"
)

function moveCoverageFile($tempFile, $coverageDest = "$RepoRoot/auto/coverage.xml") {
    # We send the coverage data to a temp file and then move it.
    # Why: Otherwise, Pester 5.5.0 puts relative path names in coverage.xml for any .ps1 files it finds under auto/.
    #      Which causes trouble e.g. in Get-CoverageReport.ps1.
    if (Test-Path $coverageDest) {
        Remove-Item $coverageDest | Out-Null
    }

    # TODO: Extract this into a function which create the 'auto' directory and also checks if .gitignore is set up to ignore it.
    $dir = Split-Path $coverageDest
    if (!(Test-Path $dir)) {
        New-Item $dir -ItemType Directory | Out-Null
    }
    try {
        Move-Item $tempFile $coverageDest -ErrorAction Stop
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

if ($CoverageType -ne "None") {
    $tempFile = [IO.Path]::GetTempFileName()
    $Configuration.CodeCoverage.OutputPath = $tempFile
    $Configuration.CodeCoverage.Enabled = [bool] $true
    $Configuration.CodeCoverage.OutputFormat = $CoverageFormat
    if ($CoverageType -eq "Subset") {
        if (!(Test-Path -PathType Container $PathToTest)) {
            if (!(Test-Path -PathType Leaf $PathToTest)) { throw "PathToTest '$PathToTest' does not exist" }
            
            # Pester coverage makes an empty xml if given a single file here.
            $guess = $PathToTest -replace ".tests.ps1", ".ps1"
            $codeFile = &$PSScriptRoot/../lib/Get-ContainingItem (Split-Path -Leaf $guess) (Split-Path -Parent $guess)
            if ($null -ne $codeFile) {
                $Configuration.CodeCoverage.Path = $codeFile.FullName
            } else {
                $Configuration.CodeCoverage.Path = $RepoRoot
            }
        } else {
            $Configuration.CodeCoverage.Path = $PathToTest
        }
    } else {
        $Configuration.CodeCoverage.Path = $RepoRoot
    }
    $Configuration.CodeCoverage.CoveragePercentTarget = & (Resolve-PratLibFile "lib/Get-CoveragePercentTarget.ps1")
}

Invoke-PesterAsJob -Configuration $Configuration

if ($CoverageType -ne "None") {
    if (Test-Path $tempFile) {
        moveCoverageFile $tempFile
    }
}