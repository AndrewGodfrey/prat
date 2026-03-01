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

    It "default mode uses Pester Normal verbosity" {
        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $repoRoot

        $outConf.Output.Verbosity.Value | Should -Be "Normal"
    }

    It "-Debugging uses Pester Diagnostic verbosity" {
        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $repoRoot -Debugging

        $outConf.Output.Verbosity.Value | Should -Be "Diagnostic"
    }

    It "defaults coverage scope to repo, if inferred production file is not found" {
        & $coverageScript -PathToTest "$repoRoot/testCb_noMatchingProfFile.tests.ps1" -RepoRoot $repoRoot

        $outConf.CodeCoverage.Enabled.Value | Should -Be $true
        $outConf.CodeCoverage.Path.Value | Should -Be @($repoRoot)
    }

    It "excludes Integration-tagged tests by default" {
        & $coverageScript -NoCoverage -PathToTest $repoRoot -RepoRoot $repoRoot

        $outConf.Filter.ExcludeTag.Value | Should -Contain "Integration"
    }

    It "includes Integration-tagged tests with -IncludeIntegrationTests" {
        & $coverageScript -NoCoverage -PathToTest $repoRoot -RepoRoot $repoRoot -IncludeIntegrationTests

        $outConf.Filter.ExcludeTag.Value | Should -Not -Contain "Integration"
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

    It "echoes test-run-summary.txt after every run" {
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

Describe "Invoke-PesterWithCodeCoverage -Debugging" {
    BeforeAll {
        function moveCoverageFile($tempFile, $coverageDest) {}
        Mock moveCoverageFile {}

        function New-PesterInfoRecord($message, $noNewLine) {
            $him = [System.Management.Automation.HostInformationMessage]::new()
            $him.Message = $message
            $him.NoNewLine = $noNewLine
            [System.Management.Automation.InformationRecord]::new($him, "Pester")
        }
    }

    It "writes InformationRecord content to host (not silently consumed via -InformationVariable)" {
        $testRoot = "$TestDrive/debug-host"
        Mock Write-Host {}
        Mock Invoke-PesterAsJob {
            New-PesterInfoRecord "[+] passes 1ms" $false
            [PSCustomObject]@{ PassedCount = 1; FailedCount = 0 }
        }

        & $coverageScript -NoCoverage -PathToTest "somePath" -RepoRoot $testRoot -Debugging

        Should -Invoke -CommandName Write-Host -ParameterFilter { "$Object" -match '\[\+\].*\d+' }
    }
}

Describe "Invoke-PesterWithCodeCoverage integration" -Tag Integration {
    # Requirements:
    #   - wsl (Windows Subsystem for Linux)
    #   - 'script' utility (present in Ubuntu by default)
    #   - pwsh installed in WSL (non-trivial; see the PowerShell docs for Ubuntu)
    #   - Pester installed in that WSL pwsh
    #
    # Caveat: paths with spaces will break $pwshCmd string interpolation below.

    It "emits each [+] line exactly once (no direct-host write duplication)" {
        Set-Content "$TestDrive\sample.Tests.ps1" `
            'Describe "x" { It "passes" { $true | Should -Be $true } }'

        $td         = $TestDrive.TrimEnd('\')
        $wslTd      = (wsl wslpath ($td -replace '\\', '/')).Trim()
        $tsWsl      = "$wslTd/typescript"
        $scriptPath = (Resolve-Path "$PSScriptRoot\..\Invoke-PesterWithCodeCoverage.ps1").Path
        $modulePath = (Resolve-Path "$PSScriptRoot\..\..\lib\PratBase\PratBase.psm1").Path

        $pwshCmd = "Import-Module $modulePath; & $scriptPath -Debugging -NoCoverage -PathToTest $td -RepoRoot $td"
        wsl bash -lc "script -q -c 'pwsh.exe -NonInteractive -Command ""$pwshCmd""' $tsWsl"

        $lines = @(
            (Get-Content "$TestDrive\typescript" -Raw) `
                -replace '\x1B\[[0-9;]*[mGKHFABCDJr]', '' `
                -replace '\x1B\[[\?][0-9;]*[hl]', '' `
                -split '\r?\n' |
                Where-Object { $_ -match '\[\+\]' }
        )

        $lines | Should -HaveCount 1
        $lines[0] | Should -Match '\[\+\].*\d+(\.\d+)?(ms|s)'
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

    It "records PathToTest and RepoRoot at the top of test-run.txt" {
        $testRoot = "$TestDrive/params-header-test"

        & $coverageScript -NoCoverage -PathToTest "focusedPath" -RepoRoot $testRoot

        $logContent = Get-Content "$testRoot/auto/testRuns/last/test-run.txt"
        $logContent[0] | Should -Match "RepoRoot:.*$([regex]::Escape($testRoot))"
        $logContent[1] | Should -Be "PathToTest: focusedPath"
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
