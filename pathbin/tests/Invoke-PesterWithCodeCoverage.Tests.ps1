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

        function getAutoDir($repoRoot) {}
        Mock getAutoDir { "$TestDrive" }

        function prepareRunDir($outputDir) {}
        Mock prepareRunDir { New-Item "$TestDrive/run" -ItemType Directory -Force | Out-Null; "$TestDrive/run" }

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

    It "writes test-run-summary.txt to testRuns/last when coverage is enabled" {
        $testRoot = "$TestDrive/enabled-test"

        Mock moveCoverageFile {
            param($tempFile, $coverageDest)
            New-Item (Split-Path $coverageDest) -ItemType Directory -Force | Out-Null
            @'
<?xml version="1.0"?>
<report name="test">
  <counter type="INSTRUCTION" missed="10" covered="90" />
  <counter type="CLASS" missed="2" covered="8" />
</report>
'@ | Set-Content $coverageDest
        }

        & $coverageScript -PathToTest "somePath" -RepoRoot $testRoot

        $summaryPath = "$testRoot/auto/testRuns/last/test-run-summary.txt"
        $summaryPath | Should -Exist
        $summary = Get-Content $summaryPath
        $summary | Should -Match "90%"
        $summary | Should -Match "Passed: 5"
        $summary | Should -Match "Failed: 2"
    }

    It "writes test-run-summary.txt to testRuns/last when coverage is disabled" {
        $testRoot = "$TestDrive/disabled-test"

        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot

        $summaryPath = "$testRoot/auto/testRuns/last/test-run-summary.txt"
        $summaryPath | Should -Exist
        $summary = Get-Content $summaryPath
        $summary | Should -Match "Passed: 5"
        $summary | Should -Match "Failed: 2"
        $summary | Should -Not -Match "90%"
    }

    It "writes output files to testRuns/last under custom -OutputDir" {
        $customOutputDir = "$TestDrive/custom-outputdir"

        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot "$TestDrive/repo" -OutputDir $customOutputDir

        "$customOutputDir/testRuns/last/test-run-summary.txt" | Should -Exist
    }

    It "echoes test-run-summary.txt to output when Verbosity is Summary" {
        $testRoot = "$TestDrive/summary-verbosity-test"

        $output = & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot -Verbosity "Summary"

        $output | Should -Match "Passed: 5"
        $output | Should -Match "Failed: 2"
    }
}

Describe "Invoke-PesterWithCodeCoverage test run directory management" {
    BeforeAll {
        function moveCoverageFile($tempFile, $coverageDest) {}
        Mock moveCoverageFile {}

        function getRetention() {}
        Mock getRetention { 2 }

        function getTimestamp() {}
        Mock getTimestamp { "2000-01-01T00-00-00-000" }

        $fakeResult = [PSCustomObject]@{ PassedCount = 3; FailedCount = 0 }
        Mock Invoke-PesterAsJob { return $fakeResult }
    }

    It "creates test-run.txt log file in testRuns/last" {
        $testRoot = "$TestDrive/log-test"

        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot

        "$testRoot/auto/testRuns/last/test-run.txt" | Should -Exist
    }

    It "rotates previous testRuns/last to a timestamped directory on second run" {
        $testRoot = "$TestDrive/rotate-test"

        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot
        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot

        $timestampDirs = Get-ChildItem "$testRoot/auto/testRuns" -Directory |
            Where-Object { $_.Name -ne 'last' }
        $timestampDirs | Should -HaveCount 1
        "$testRoot/auto/testRuns/last/test-run-summary.txt" | Should -Exist
    }

    It "applies retention: removes oldest timestamp dirs beyond N=2" {
        $testRoot = "$TestDrive/retention-test"

        # Use a [ref] counter so the closure captures a mutable object (not a scope-sensitive $script: var)
        $counter = [ref] 0
        Mock getTimestamp {
            $counter.Value++
            "2000-01-01T00-00-00-{0:D3}" -f $counter.Value
        }

        # Run 4 times: run 1 creates 'last'; runs 2-4 rotate it to 001, 002, 003.
        # With N=2: after run 4 there are 3 timestamp dirs, so 001 (oldest) is deleted.
        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot
        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot
        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot
        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot

        "$testRoot/auto/testRuns/2000-01-01T00-00-00-001" | Should -Not -Exist
        "$testRoot/auto/testRuns/2000-01-01T00-00-00-002" | Should -Exist
        "$testRoot/auto/testRuns/2000-01-01T00-00-00-003" | Should -Exist
    }
}
