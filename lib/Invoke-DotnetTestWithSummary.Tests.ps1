BeforeAll {
    Import-Module "$PSScriptRoot/PratBase/PratBase.psd1" -Force
    $script:dotnetScript = "$PSScriptRoot/Invoke-DotnetTestWithSummary.ps1"
}

Describe "Invoke-DotnetTestWithSummary filter" {
    BeforeAll {
        # Create fake dotnet.cmd that outputs xUnit-style test results.
        # Exit 0 to prevent the script's 'exit $exitCode' from terminating the test runner.
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
