BeforeAll {
    Import-Module "$PSScriptRoot/../../lib/PratBase/PratBase.psd1"

    $coverageScript = "$PSScriptRoot/../Invoke-PesterWithCodeCoverage.ps1"
}

Describe "Invoke-PesterWithCodeCoverage" {
    BeforeAll {
        function moveCoverageFile($tempFile, $coverageDest) {}
        Mock moveCoverageFile {}

        function getRetention() {}
        Mock getRetention { 5 }

        $script:outConf = $null
        $refOutConf = [ref] $script:outConf
        Mock Invoke-PesterAsJob { $refOutConf.Value = $Configuration }

        $repoRoot = (Resolve-Path "$PSScriptRoot/../../pathbin/tests/testCb").Path
        $script:outputDir = "$TestDrive/runs"
    }

    It "calls Invoke-PesterAsJob" {
        & $coverageScript -NoCoverage -PathToTest $repoRoot -RepoRoot $repoRoot -OutputDir $script:outputDir

        Should -Invoke Invoke-PesterAsJob -Times 1
        $outConf.Run.Path.Value | Should -Be @($repoRoot)
        $outConf.Run.PassThru.Value | Should -Be $true
        $outConf.CodeCoverage.Enabled.Value | Should -Be $false
    }

    It "supports code coverage by default" {
        & $coverageScript -PathToTest $repoRoot -RepoRoot $repoRoot -OutputDir $script:outputDir

        $outConf.Run.Path.Value | Should -Be @($repoRoot)
        $outConf.CodeCoverage.Enabled.Value | Should -Be $true
        $outConf.CodeCoverage.OutputFormat.Value | Should -Be "CoverageGutters"  # For integration with vscode "Coverage Gutters" extension.
        $outConf.CodeCoverage.Path.Value | Should -Be @($repoRoot)
    }

    It "supports coverage with a subset" {
        & $coverageScript -PathToTest "$repoRoot/subdir" -RepoRoot $repoRoot -OutputDir $script:outputDir

        $outConf.Run.Path.Value | Should -Be @("$repoRoot/subdir")
        $outConf.CodeCoverage.Enabled.Value | Should -Be $true
        $outConf.CodeCoverage.Path.Value | Should -Be @("$repoRoot\subdir") # The backslash is a quirk of Get-CoverageScope.
    }

    It "scopes coverage to inferred production file when PathToTest is a test file" {
        & $coverageScript -PathToTest "$repoRoot/testCb_fileWithTests.Tests.ps1" -RepoRoot $repoRoot -OutputDir $script:outputDir

        $outConf.CodeCoverage.Enabled.Value | Should -Be $true
        $outConf.CodeCoverage.Path.Value[0] | Should -BeLike "*testCb_fileWithTests.ps1*"
        $outConf.Run.Path.Value[0] | Should -BeLike "*testCb_fileWithTests.Tests.ps1*"
    }

    It "default mode uses Pester Normal verbosity" {
        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $repoRoot -OutputDir $script:outputDir

        $outConf.Output.Verbosity.Value | Should -Be "Normal"
    }

    It "defaults coverage scope to repo, if inferred production file is not found" {
        & $coverageScript -PathToTest "$repoRoot/testCb_noMatchingProfFile.tests.ps1" -RepoRoot $repoRoot -OutputDir $script:outputDir

        $outConf.CodeCoverage.Enabled.Value | Should -Be $true
        $outConf.CodeCoverage.Path.Value | Should -Be @($repoRoot)
    }

    It "excludes Integration-tagged tests by default" {
        & $coverageScript -NoCoverage -PathToTest $repoRoot -RepoRoot $repoRoot -OutputDir $script:outputDir

        $outConf.Filter.ExcludeTag.Value | Should -Contain "Integration"
    }

    It "includes Integration-tagged tests with -IncludeIntegrationTests" {
        & $coverageScript -NoCoverage -PathToTest $repoRoot -RepoRoot $repoRoot -IncludeIntegrationTests -OutputDir $script:outputDir

        $outConf.Filter.ExcludeTag.Value | Should -Not -Contain "Integration"
    }

    It "-Integration runs only Integration-tagged tests" {
        & $coverageScript -NoCoverage -PathToTest $repoRoot -RepoRoot $repoRoot -Integration -OutputDir $script:outputDir

        $outConf.Filter.Tag.Value | Should -Contain "Integration"
        $outConf.Filter.ExcludeTag.Value | Should -Not -Contain "Integration"
    }

    It "-Integration and -IncludeIntegrationTests together warns and -Integration wins" {
        $warnings = & $coverageScript -NoCoverage -PathToTest $repoRoot -RepoRoot $repoRoot -Integration -IncludeIntegrationTests -OutputDir $script:outputDir 3>&1 |
            Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

        $warnings | Should -Not -BeNullOrEmpty
        $outConf.Filter.Tag.Value | Should -Contain "Integration"
    }

    It "-UseAlternateCollector emits a warning and continues" {
        $warnings = & $coverageScript -NoCoverage -PathToTest $repoRoot -RepoRoot $repoRoot -UseAlternateCollector -OutputDir $script:outputDir 3>&1 |
            Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

        $warnings | Should -Not -BeNullOrEmpty
        $warnings[0].Message | Should -Match "no alternate collector"
    }
}

Describe "Invoke-PesterWithCodeCoverage summary file" {
    BeforeAll {
        function moveCoverageFile($tempFile, $coverageDest) {}
        Mock moveCoverageFile {}

        function getRetention() {}
        Mock getRetention { 5 }

        $fakeResult = [PSCustomObject]@{ PassedCount = 5; FailedCount = 2 }

        Mock Invoke-PesterAsJob { return $fakeResult }
    }

    It "writes summary.txt to testRuns/last when coverage is enabled" {
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

        $summaryPath = "$testRoot/auto/testRuns/last/summary.txt"
        $summaryPath | Should -Exist
        $summary = Get-Content $summaryPath
        $summary | Should -Match "90%"
        $summary | Should -Match "Passed: 5"
        $summary | Should -Match "Failed: 2"
        $summary | Should -Match '\d+(\.\d+)?(s|m)'
    }

    It "writes summary.txt to testRuns/last when coverage is disabled" {
        $testRoot = "$TestDrive/disabled-test"

        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot

        $summaryPath = "$testRoot/auto/testRuns/last/summary.txt"
        $summaryPath | Should -Exist
        $summary = Get-Content $summaryPath
        $summary | Should -Match "Passed: 5"
        $summary | Should -Match "Failed: 2"
        $summary | Should -Match '\d+(\.\d+)?(s|m)'
        $summary | Should -Not -Match "90%"
    }

    It "writes output files to last under custom -OutputDir" {
        $customOutputDir = "$TestDrive/custom-outputdir"

        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot "$TestDrive/repo" -OutputDir $customOutputDir

        "$customOutputDir/last/summary.txt" | Should -Exist
    }

    It "echoes summary.txt after every run" {
        $testRoot = "$TestDrive/summary-always-test"

        $output = & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot

        $output | Where-Object { $_ -match "Passed: 5" } | Should -Not -BeNullOrEmpty
        $output | Where-Object { $_ -match "Failed: 2" } | Should -Not -BeNullOrEmpty
    }
}

Describe "Invoke-PesterWithCodeCoverage smart filter" {
    BeforeAll {
        function moveCoverageFile($tempFile, $coverageDest) {}
        Mock moveCoverageFile {}

        function getRetention() {}
        Mock getRetention { 5 }

        Mock Invoke-PesterAsJob {
            "[+] some/test.Tests.ps1 1.23s"
            [PSCustomObject]@{ PassedCount = 1; FailedCount = 0 }
        }

        function New-PesterInfoRecord($message, $noNewLine) {
            $him = [System.Management.Automation.HostInformationMessage]::new()
            $him.Message = $message
            $him.NoNewLine = $noNewLine
            [System.Management.Automation.InformationRecord]::new($him, "Pester")
        }
    }

    It "passes [+] lines as progress" {
        Mock Write-Progress {} -Verifiable
        $testRoot = "$TestDrive/filter-pass"

        $output = & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot

        $output | Where-Object { $_ -match '\[\+\]' } | Should -BeNullOrEmpty
        Should -Invoke -CommandName Write-Progress -Times 1 -ParameterFilter {$Status -match 'test\.Tests\.ps1'}
    }

    It "suppresses lines that are not [+] or [-]" {
        $testRoot = "$TestDrive/filter-suppress"
        Mock Invoke-PesterAsJob {
            "Starting test run..."
            "Some verbose line"
            "[+] test.Tests.ps1 1.23s"
            [PSCustomObject]@{ PassedCount = 1; FailedCount = 0 }
        }

        $output = & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot

        $output | Where-Object { $_ -match 'Starting test run' } | Should -BeNullOrEmpty
        $output | Where-Object { $_ -match 'verbose line' } | Should -BeNullOrEmpty
    }

    It "accumulates and shows failure blocks" {
        $testRoot = "$TestDrive/filter-fail"
        Mock Invoke-PesterAsJob {
            "[-] failing test name 45ms"
            "   Expected 'foo' but got 'bar'"
            [PSCustomObject]@{ PassedCount = 0; FailedCount = 1 }
        }

        $output = & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot

        $output | Where-Object { $_ -match '\[-\]' } | Should -Not -BeNullOrEmpty
        $output | Where-Object { $_ -match "Expected 'foo'" } | Should -Not -BeNullOrEmpty
    }

    It "does not show OK when tests fail" {
        $testRoot = "$TestDrive/filter-fail-no-ok"
        Mock Invoke-PesterAsJob {
            "[-] a failing test 10ms"
            [PSCustomObject]@{ PassedCount = 0; FailedCount = 1 }
        }

        $output = & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot

        $output | Should -Not -Contain "`e[92mOK`e[0m"
    }

    It "emits suppression hint and log file path when failures exceed threshold" {
        $testRoot = "$TestDrive/filter-suppress-hint"
        Mock Invoke-PesterAsJob {
            for ($i = 1; $i -le 7; $i++) { "[-] failing test $i 10ms" }
            [PSCustomObject]@{ PassedCount = 0; FailedCount = 7 }
        }

        $output = & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot

        $output | Where-Object { $_ -match 'suppressed' }    | Should -Not -BeNullOrEmpty
        $output | Where-Object { $_ -match 'test-run\.txt' } | Should -Not -BeNullOrEmpty
    }

    It "mentions log file when failures are within threshold" {
        $testRoot = "$TestDrive/filter-log-hint"
        Mock Invoke-PesterAsJob {
            "[-] one failing test 10ms"
            [PSCustomObject]@{ PassedCount = 0; FailedCount = 1 }
        }

        $output = & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot

        $output | Where-Object { $_ -match 'test-run\.txt' } | Should -Not -BeNullOrEmpty
        $output | Where-Object { $_ -match 'suppressed' }    | Should -BeNullOrEmpty
    }

    It "does not mention log file when all tests pass" {
        $testRoot = "$TestDrive/filter-no-hint"
        Mock Invoke-PesterAsJob {
            "[+] some/test.Tests.ps1 1.23s"
            [PSCustomObject]@{ PassedCount = 3; FailedCount = 0 }
        }

        $output = & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot

        $output | Where-Object { $_ -match 'test-run\.txt' } | Should -BeNullOrEmpty
    }

    It "propagates exception when Invoke-PesterAsJob throws" {
        $testRoot = "$TestDrive/exception-propagate"
        Mock Invoke-PesterAsJob { throw "Pester crashed" }

        { & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot } |
            Should -Throw "Pester crashed"
    }

    It "creates log file even when Invoke-PesterAsJob throws" {
        $testRoot = "$TestDrive/exception-log"
        Mock Invoke-PesterAsJob { throw "Pester crashed" }

        try { & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot } catch {}

        "$testRoot/auto/testRuns/last/test-run.txt" | Should -Exist
    }

    It "buffers noNewLine start record and combines with timing to emit one line" {
        $testRoot = "$TestDrive/filter-buffer"
        Mock Invoke-PesterAsJob {
            New-PesterInfoRecord "[+] some/test.Tests.ps1" $true   # noNewLine=true: buffer
            New-PesterInfoRecord " 1.23s (0.5s|0.73s)"    $false  # noNewLine=false: flush combined
            [PSCustomObject]@{ PassedCount = 1; FailedCount = 0 }
        }
        Mock Write-Progress {} -Verifiable

        $output = & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot

        # Combined line must not appear
        $output | Where-Object { $_ -match '\[\+\] some/test\.Tests\.ps1 1\.23s' } | Should -BeNullOrEmpty
        # Start line alone must not appear
        $output | Where-Object { $_ -eq "`e[92m[+] some/test.Tests.ps1`e[0m" } | Should -BeNullOrEmpty

        Should -Invoke -CommandName Write-Progress -Times 1 -ParameterFilter {$Status -match 'test\.Tests\.ps1'}
    }
}


Describe "Invoke-PesterWithCodeCoverage test run directory management" {
    BeforeAll {
        function moveCoverageFile($tempFile, $coverageDest) {}
        Mock moveCoverageFile {}

        function getRetention() {}
        Mock getRetention { 2 }

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
        "$testRoot/auto/testRuns/last/summary.txt" | Should -Exist
    }

    It "records PathToTest and RepoRoot at the top of test-run.txt" {
        $testRoot = "$TestDrive/params-header-test"

        & $coverageScript -NoCoverage -PathToTest "focusedPath" -RepoRoot $testRoot

        $logContent = Get-Content "$testRoot/auto/testRuns/last/test-run.txt"
        $logContent[0] | Should -Match "RepoRoot:.*$([regex]::Escape($testRoot))"
        $logContent[1] | Should -Be "PathToTest: focusedPath"
    }

    It "applies retention: removes oldest timestamp dirs beyond N=2" {
        $testRoot = "$TestDrive/retention-test"

        # Run 4 times: run 1 creates 'last'; runs 2-4 rotate it to timestamp dirs.
        # With N=2: after run 4 there are 3 timestamp dirs, so the oldest is deleted.
        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot
        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot
        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot
        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot

        $timestampDirs = Get-ChildItem "$testRoot/auto/testRuns" -Directory |
            Where-Object { $_.Name -ne 'last' }
        $timestampDirs | Should -HaveCount 2
    }
}
