BeforeAll {
    Import-Module "$PSScriptRoot/PratBase/PratBase.psd1" -Force
    $script:dotnetScript = "$PSScriptRoot/Invoke-DotnetTestWithSummary.ps1"
}

Describe "Invoke-DotnetTestWithSummary filter" {
    BeforeAll {
        # Create fake dotnet.cmd that outputs xUnit-style test results.
        $script:fakeDotnetDir = Join-Path $TestDrive "fakedotnet"
        New-Item $script:fakeDotnetDir -ItemType Directory | Out-Null
        Set-Content (Join-Path $script:fakeDotnetDir "dotnet.cmd") (@'
@echo off
echo Test run for foo.dll (.NETCoreApp)
echo Starting test execution, please wait...
echo [xUnit.net 00:00:00.11]     HelloWorld.Tests.FailingTest [FAIL]
echo.
echo Failed!  - Failed:     1, Passed:     2, Skipped:     0, Total:     3, Duration: 1 ms
exit /b 0
'@.Trim())
    }

    It "shows xUnit [FAIL] lines in red" {
        $repoRoot = Join-Path $TestDrive "repo-xunit"
        New-Item $repoRoot -ItemType Directory | Out-Null
        $savedPath = $env:PATH
        $env:PATH = "$script:fakeDotnetDir;$env:PATH"
        try {
            $output = & $script:dotnetScript -TestArgs @("fake.csproj") -NoCoverage -RepoRoot $repoRoot -OutputDir "$repoRoot/auto/testRuns"
        } finally {
            $env:PATH = $savedPath
        }

        $output | Where-Object { $_ -match '\[FAIL\]' } | Should -Not -BeNullOrEmpty
    }

    It "does not show classic-format 'Failed!' summary line (consumed by parseTestResult)" {
        $repoRoot = Join-Path $TestDrive "repo-summary"
        New-Item $repoRoot -ItemType Directory | Out-Null
        $savedPath = $env:PATH
        $env:PATH = "$script:fakeDotnetDir;$env:PATH"
        try {
            $output = & $script:dotnetScript -TestArgs @("fake.csproj") -NoCoverage -RepoRoot $repoRoot -OutputDir "$repoRoot/auto/testRuns"
        } finally {
            $env:PATH = $savedPath
        }

        # The 'Failed! - ...' line is parsed by parseTestResult and suppressed (we render our own summary)
        $output | Where-Object { $_ -match '^Failed!' } | Should -BeNullOrEmpty
    }

    It "warns when coverage is requested but no coverage file is produced" {
        $repoRoot = Join-Path $TestDrive "repo-coverage-warn"
        New-Item $repoRoot -ItemType Directory | Out-Null
        $savedPath = $env:PATH
        $env:PATH = "$script:fakeDotnetDir;$env:PATH"
        try {
            $warnings = & $script:dotnetScript -TestArgs @("fake.csproj") -RepoRoot $repoRoot -OutputDir "$repoRoot/auto/testRuns" 3>&1 |
                Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
        } finally {
            $env:PATH = $savedPath
        }

        $warnings | Should -Not -BeNullOrEmpty
        $warnings[0].Message | Should -Match "coverlet"
    }

    It "-UseAlternateCollector routes to dotnet-coverage collector" {
        $repoRoot = Join-Path $TestDrive "repo-alt-collector"
        New-Item $repoRoot -ItemType Directory | Out-Null
        # Remove dotnet-coverage's directory from PATH so the script's "not found" check fires.
        # Keeps git and other tools intact; only strips the one tool we're testing is absent.
        $savedPath = $env:PATH
        $dcSource = (Get-Command dotnet-coverage -ErrorAction SilentlyContinue)?.Source
        $dcDir    = if ($dcSource) { Split-Path $dcSource -Parent } else { $null }
        $filteredPath = (($savedPath -split ';') | Where-Object { $_ -ne $dcDir }) -join ';'
        $env:PATH = "$script:fakeDotnetDir;$filteredPath"
        try {
            { & $script:dotnetScript -TestArgs @("fake.csproj") -RepoRoot $repoRoot -UseAlternateCollector } |
                Should -Throw "*dotnet-coverage not found*"
        } finally {
            $env:PATH = $savedPath
        }
    }
}

Describe "Invoke-DotnetTestWithSummary console logger" {
    BeforeAll {
        $script:argsFakeDir = Join-Path $TestDrive "fakedotnet-args"
        $script:argsFile    = Join-Path $script:argsFakeDir "args.txt"
        New-Item $script:argsFakeDir -ItemType Directory | Out-Null
        Set-Content (Join-Path $script:argsFakeDir "dotnet.cmd") (@'
@echo off
rem Redirection first: a trailing digit immediately before ">" would be read as a stream handle.
>"%~dp0args.txt" echo %*
echo Passed!  - Failed:     0, Passed:     1, Skipped:     0, Total:     1, Duration: 1 ms
exit /b 0
'@.Trim())

        function runAndCaptureArgs([string[]] $testArgs, $repoRoot) {
            New-Item $repoRoot -ItemType Directory -Force | Out-Null
            # Deleted first so a run that never reaches the fake fails instead of reading the
            # previous test's args.
            Remove-Item $script:argsFile -ErrorAction Ignore
            $savedPath = $env:PATH
            $env:PATH = "$script:argsFakeDir;$env:PATH"
            try {
                & $script:dotnetScript -TestArgs $testArgs -NoCoverage -RepoRoot $repoRoot -OutputDir "$repoRoot/auto/testRuns" | Out-Null
            } finally {
                $env:PATH = $savedPath
            }
            Get-Content $script:argsFile -Raw
        }
    }

    It "adds a minimal-verbosity console logger ahead of the caller's args" {
        $recorded = runAndCaptureArgs @("fake.csproj") "$TestDrive/repo-logger-default"

        # Ahead of $TestArgs: a caller ending its args with a "--" runsettings block would
        # otherwise swallow the logger spec.
        $recorded | Should -Match '--logger "?console;verbosity=minimal"?\s+fake\.csproj'
    }

    It "doesn't add a second console logger when the caller supplies one" {
        $recorded = runAndCaptureArgs @("fake.csproj", "--logger", "console;verbosity=detailed") "$TestDrive/repo-logger-custom"

        $recorded | Should -Match 'console;verbosity=detailed'
        $recorded | Should -Not -Match 'verbosity=minimal'
    }

    It "recognizes a caller's console logger given as '<arg>'" -ForEach @(
        @{ arg = '--logger:console;verbosity=detailed'; dir = 'repo-logger-colon' }
        @{ arg = '--logger=console;verbosity=detailed'; dir = 'repo-logger-equals' }
        @{ arg = '-l:console;verbosity=detailed';       dir = 'repo-logger-short' }
    ) {
        $recorded = runAndCaptureArgs @("fake.csproj", $arg) "$TestDrive/$dir"

        $recorded | Should -Match 'console;verbosity=detailed'
        $recorded | Should -Not -Match 'verbosity=minimal'
    }
}

Describe "Invoke-DotnetTestWithSummary zero-test classification" {
    BeforeAll {
        function newFakeDotnet($dir, $summaryLine) {
            New-Item $dir -ItemType Directory -Force | Out-Null
            Set-Content "$dir/dotnet.cmd" (@"
@echo off
echo Test run for foo.dll (.NETCoreApp)
echo Starting test execution, please wait...
echo $summaryLine
exit /b 0
"@.Trim()) -Encoding utf8NoBOM
            $dir
        }

        function runWithFakeDotnet($fakeDir, $repoRoot) {
            New-Item $repoRoot -ItemType Directory -Force | Out-Null
            $savedPath = $env:PATH
            $env:PATH = "$fakeDir;$env:PATH"
            try {
                & $script:dotnetScript -TestArgs @("fake.csproj") -NoCoverage -RepoRoot $repoRoot `
                    -OutputDir "$repoRoot/auto/testRuns" -PassThru
            } finally {
                $env:PATH = $savedPath
            }
        }
    }

    It "reports a fatal error when the run reported a total of 0 tests" {
        $fake = newFakeDotnet "$TestDrive/fakedotnet-none" `
            "Passed!  - Failed:     0, Passed:     0, Skipped:     0, Total:     0, Duration: 1 ms"

        $result = runWithFakeDotnet $fake "$TestDrive/repo-dn-no-tests"

        $result.FatalError | Should -Match 'no tests discovered'
    }

    It "reports a fatal error when the run produced no summary line at all" {
        # Measured against a real xunit project with a filter matching nothing (2026-08): dotnet
        # test prints "A total of 1 test files matched the specified pattern.", no result summary,
        # and exits 0. Nothing ran, and nothing said so.
        $fake = newFakeDotnet "$TestDrive/fakedotnet-silent" `
            "A total of 1 test files matched the specified pattern."

        $result = runWithFakeDotnet $fake "$TestDrive/repo-dn-silent"

        $result.FatalError | Should -Match 'no tests discovered'
    }

    It "leaves an ordinary passing run free of a fatal error" {
        $fake = newFakeDotnet "$TestDrive/fakedotnet-pass" `
            "Passed!  - Failed:     0, Passed:     3, Skipped:     0, Total:     3, Duration: 1 ms"

        $result = runWithFakeDotnet $fake "$TestDrive/repo-dn-passing"

        $result.FatalError | Should -BeNullOrEmpty
        $result.Passed     | Should -Be 3
    }
}
Describe "Invoke-DotnetTestWithSummary failure display budget" {
    BeforeAll {
        # A failing test shows up twice: the xUnit adapter's live diagnostic during the run, then
        # the console logger's detail block afterwards.
        function newFailingFakeDotnet($dir, [string[]] $testNames) {
            New-Item $dir -ItemType Directory -Force | Out-Null
            $lines  = @('@echo off',
                        'echo Test run for foo.dll (.NETCoreApp)',
                        'echo Starting test execution, please wait...')
            $lines += $testNames | ForEach-Object { "echo [xUnit.net 00:00:00.11]     $_ [FAIL]" }
            $lines += $testNames | ForEach-Object {
                "echo   Failed $_ [1 ms]"
                'echo   Error Message:'
                'echo    Assert.Equal() Failure'
            }
            $lines += "echo Failed!  - Failed:     $($testNames.Count), Passed:     0, Skipped:     0, " +
                      "Total:     $($testNames.Count), Duration: 1 ms"
            $lines += 'exit /b 0'
            Set-Content "$dir/dotnet.cmd" ($lines -join "`r`n") -Encoding utf8NoBOM
            $dir
        }

        function runFailingTests($fakeDir, $repoRoot, [switch] $PassThru) {
            New-Item $repoRoot -ItemType Directory -Force | Out-Null
            $savedPath = $env:PATH
            $env:PATH = "$fakeDir;$env:PATH"
            try {
                & $script:dotnetScript -TestArgs @("fake.csproj") -NoCoverage -RepoRoot $repoRoot `
                    -OutputDir "$repoRoot/auto/testRuns" -PassThru:$PassThru
            } finally {
                $env:PATH = $savedPath
            }
        }

        $script:threeFailures = @('HelloWorld.Tests.Alpha', 'HelloWorld.Tests.Beta', 'HelloWorld.Tests.Gamma')

        # A failure line carrying no test name in either shape.
        function newUnnamedFailureFakeDotnet($dir) {
            New-Item $dir -ItemType Directory -Force | Out-Null
            Set-Content "$dir/dotnet.cmd" (@'
@echo off
echo Test run for foo.dll (.NETCoreApp)
echo Starting test execution, please wait...
echo Failed
echo Failed!  - Failed:     1, Passed:     0, Skipped:     0, Total:     1, Duration: 1 ms
exit /b 0
'@.Trim()) -Encoding utf8NoBOM
            $dir
        }
    }

    It "counts each failing test once, not once per line naming it" {
        $fake = newFailingFakeDotnet "$TestDrive/fake-3fail" $script:threeFailures

        $result = runFailingTests $fake "$TestDrive/repo-3fail" -PassThru

        $result.Failed       | Should -Be 3
        $result.FailuresSeen | Should -Be 3
    }

    It "shows every failing test's detail when the run is under the budget" {
        $fake = newFailingFakeDotnet "$TestDrive/fake-3fail-shown" $script:threeFailures

        $output = runFailingTests $fake "$TestDrive/repo-3fail-shown"

        $output | Where-Object { $_ -match 'Failed HelloWorld\.Tests\.Gamma' } | Should -Not -BeNullOrEmpty
    }

    It "stops at the threshold, counting tests rather than output lines" {
        $names = 1..7 | ForEach-Object { "HelloWorld.Tests.Case$_" }
        $fake  = newFailingFakeDotnet "$TestDrive/fake-7fail" $names

        $result = runFailingTests $fake "$TestDrive/repo-7fail" -PassThru

        $result.Failed       | Should -Be 7
        $result.FailuresSeen | Should -Be $result.FailureThreshold
    }
    It "counts a failure line that names no test on its own" {
        $fake = newUnnamedFailureFakeDotnet "$TestDrive/fake-unnamed"

        $result = runFailingTests $fake "$TestDrive/repo-unnamed" -PassThru

        $result.FailuresSeen | Should -Be 1
    }
}
