BeforeAll {
    Import-Module "$PSScriptRoot/../../lib/PratBase/PratBase.psd1"

    $coverageScript = "$PSScriptRoot/../Invoke-PesterWithCodeCoverage.ps1"
}

Describe "Invoke-PesterWithCodeCoverage" {
    BeforeAll {
        function moveCoverageFile($tempFile, $coverageDest) {}
        Mock moveCoverageFile {}

        function writeTestRunSummary($result, $coverageSrc, $summaryDest) {}
        Mock writeTestRunSummary {}

        $script:outConf = $null
        $refOutConf = [ref] $script:outConf
        Mock Invoke-PesterAsJob { $refOutConf.Value = $Configuration }

        $repoRoot = (Resolve-Path "$PSScriptRoot/../../pathbin/tests/testCb").Path
    }

    It "calls Invoke-PesterAsJob" {
        & $coverageScript -NoCoverage -PathToTest $repoRoot -RepoRoot $repoRoot

        Should -Invoke Invoke-PesterAsJob -Times 1
        $outConf.Run.Path.Value | Should -Be @($repoRoot)
        $outConf.Run.PassThru.Value | Should -Be $true
        $outConf.CodeCoverage.Enabled.Value | Should -Be $false
        $outConf.Output.Verbosity.Value | Should -Not -Be "Detailed"
    }

    It "supports -Verbose" {
        & $coverageScript -NoCoverage -PathToTest $repoRoot -RepoRoot $repoRoot -Verbose

        $outConf.Output.Verbosity.Value | Should -Be "Detailed"
    }

    It "supports code coverage by default" {
        & $coverageScript -PathToTest $repoRoot -RepoRoot $repoRoot

        $outConf.Run.Path.Value | Should -Be @($repoRoot)
        $outConf.CodeCoverage.Enabled.Value | Should -Be $true
        $outConf.CodeCoverage.OutputFormat.Value | Should -Be "CoverageGutters"  # For integration with vscode "Coverage Gutters" extension.
        $outConf.CodeCoverage.Path.Value | Should -Be @($repoRoot)
    }

    It "supports coverage with a subset" {
        & $coverageScript -PathToTest "$repoRoot/subdir" -RepoRoot $repoRoot

        $outConf.Run.Path.Value | Should -Be @("$repoRoot/subdir")
        $outConf.CodeCoverage.Enabled.Value | Should -Be $true
        $outConf.CodeCoverage.Path.Value | Should -Be @("$repoRoot\subdir") # The backslash is a quirk of Get-CoverageScope.
    }

    It "scopes coverage to inferred production file when PathToTest is a test file" {
        & $coverageScript -PathToTest "$repoRoot/testCb_fileWithTests.Tests.ps1" -RepoRoot $repoRoot

        $outConf.CodeCoverage.Enabled.Value | Should -Be $true
        $outConf.CodeCoverage.Path.Value[0] | Should -BeLike "*testCb_fileWithTests.ps1*"
        $outConf.Run.Path.Value[0] | Should -BeLike "*testCb_fileWithTests.Tests.ps1*"
    }

    It "maps Summary verbosity to Pester None" {
        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $repoRoot -Verbosity "Summary"

        $outConf.Output.Verbosity.Value | Should -Be "None"
    }

    It "maps Failures verbosity to Pester Detailed" {
        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $repoRoot -Verbosity "Failures"

        $outConf.Output.Verbosity.Value | Should -Be "Detailed"
    }

    It "maps Debugging verbosity to Pester Diagnostic" {
        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $repoRoot -Verbosity "Debugging"

        $outConf.Output.Verbosity.Value | Should -Be "Diagnostic"
    }

    It "defaults coverage scope to repo, if inferred production file is not found" {
        & $coverageScript -PathToTest "$repoRoot/testCb_noMatchingProfFile.tests.ps1" -RepoRoot $repoRoot

        $outConf.CodeCoverage.Enabled.Value | Should -Be $true
        $outConf.CodeCoverage.Path.Value | Should -Be @($repoRoot)
    }
}

Describe "Invoke-PesterWithCodeCoverage summary file" {
    BeforeAll {
        function moveCoverageFile($tempFile, $coverageDest) {}
        Mock moveCoverageFile {}

        $fakeResult = [PSCustomObject]@{ PassedCount = 5; FailedCount = 2 }

        Mock Invoke-PesterAsJob { return $fakeResult }
    }

    It "writes test-run-summary.txt when coverage is enabled" {
        $testRoot = "$TestDrive/enabled-test"
        New-Item "$testRoot/auto" -ItemType Directory -Force
        @'
<?xml version="1.0"?>
<report name="test">
  <counter type="INSTRUCTION" missed="10" covered="90" />
  <counter type="CLASS" missed="2" covered="8" />
</report>
'@ | Set-Content "$testRoot/auto/coverage.xml"

        & $coverageScript -PathToTest "somePath" -RepoRoot $testRoot

        $summaryPath = "$testRoot/auto/test-run-summary.txt"
        $summaryPath | Should -Exist
        $summary = Get-Content $summaryPath
        $summary | Should -Match "90%"
        $summary | Should -Match "Passed: 5"
        $summary | Should -Match "Failed: 2"
    }

    It "writes test-run-summary.txt when coverage is disabled" {
        $testRoot = "$TestDrive/disabled-test"

        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot

        $summaryPath = "$testRoot/auto/test-run-summary.txt"
        $summaryPath | Should -Exist
        $summary = Get-Content $summaryPath
        $summary | Should -Match "Passed: 5"
        $summary | Should -Match "Failed: 2"
        $summary | Should -Not -Match "90%"
    }
}
