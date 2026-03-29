BeforeAll {
    Import-Module "$PSScriptRoot/PratBase/PratBase.psd1" -Force
    $script:harness = "$PSScriptRoot/Invoke-TestWithSummary.ps1"

    # Minimal harness invocation with all required params.
    # Pass $extra to override individual params.
    function invokeHarness([hashtable] $extra = @{}) {
        $p = @{
            StartTime       = $extra.ContainsKey('StartTime')       ? $extra.StartTime       : [DateTimeOffset]::UtcNow
            RepoRoot        = $extra.ContainsKey('RepoRoot')        ? $extra.RepoRoot        : "$TestDrive/repo-$(New-Guid)"
            CoverageUnit    = $extra.ContainsKey('CoverageUnit')    ? $extra.CoverageUnit    : "Lines"
            InitialState    = $extra.ContainsKey('InitialState')    ? $extra.InitialState    : @{ failuresSeen = 0 }
            TestCommand     = $extra.ContainsKey('TestCommand')     ? $extra.TestCommand     : { }
            ProcessLine     = $extra.ContainsKey('ProcessLine')     ? $extra.ProcessLine     : { param($l, $s) $null }
            RenderResult    = $extra.ContainsKey('RenderResult')    ? $extra.RenderResult    : { param($s) }
            GetCoverageFile = $extra.ContainsKey('GetCoverageFile') ? $extra.GetCoverageFile : { param($rd) $null }
            GetTestResult   = $extra.ContainsKey('GetTestResult')   ? $extra.GetTestResult   : { param($s) @{ Passed = 3; Failed = 0; FatalError = $null } }
        }
        if ($extra.ContainsKey('LogHeader'))     { $p.LogHeader     = $extra.LogHeader }
        if ($extra.ContainsKey('OutputDir'))     { $p.OutputDir     = $extra.OutputDir }
        & $script:harness @p
    }
}

Describe "Invoke-TestWithSummary" {
    BeforeAll {
        Mock Write-TestRunResult { }
        Mock Get-CoveragePercentTarget -ModuleName PratBase { 70 }
        function getRetention() {}
        Mock getRetention { 5 }
    }

    It "creates runDir under <RepoRoot>/auto/testRuns/last" {
        $root = "$TestDrive/repo-rundir"
        invokeHarness @{ RepoRoot = $root }
        "$root/auto/testRuns/last" | Should -Exist
    }

    It "writes LogHeader lines to test-run.txt" {
        $root = "$TestDrive/repo-header"
        invokeHarness @{
            RepoRoot  = $root
            LogHeader = @("RepoRoot: $root", "TestArgs: foo.csproj", "")
        }
        $log = Get-Content "$root/auto/testRuns/last/test-run.txt"
        $log[0] | Should -Match 'RepoRoot:'
        $log[1] | Should -Be "TestArgs: foo.csproj"
    }

    It "calls Write-TestRunResult with Passed/Failed from GetTestResult" {
        invokeHarness @{
            GetTestResult = { param($s) @{ Passed = 7; Failed = 2; FatalError = $null } }
        }
        Should -Invoke Write-TestRunResult -Times 1 -ParameterFilter { $Passed -eq 7 -and $Failed -eq 2 }
    }

    It "calls Write-TestRunResult with FatalError from GetTestResult" {
        invokeHarness @{
            GetTestResult = { param($s) @{ Passed = $null; Failed = $null; FatalError = "exit code: 1" } }
        }
        Should -Invoke Write-TestRunResult -Times 1 -ParameterFilter { $FatalError -eq "exit code: 1" }
    }

    It "passes coverage summary built from GetCoverageFile path" {
        $covXml = "$TestDrive/cov.xml"
        @'
<?xml version="1.0"?>
<coverage line-rate="0.9" lines-covered="9" lines-valid="10">
  <packages><package name="p"><classes><class filename="F.cs"/></classes></package></packages>
</coverage>
'@ | Set-Content $covXml -Encoding utf8NoBOM

        invokeHarness @{
            CoverageUnit    = "Lines"
            GetCoverageFile = { param($rd) $covXml }
        }
        Should -Invoke Write-TestRunResult -Times 1 -ParameterFilter { $CoverageSummary -match '90%' }
    }

    It "injects state.logFile for use by ProcessLine" {
        $root  = "$TestDrive/repo-logfile"
        $state = @{ failuresSeen = 0 }
        invokeHarness @{
            RepoRoot     = $root
            InitialState = $state
            TestCommand  = { "hello" }
            ProcessLine  = { param($l, $s) $s.capturedLogFile = $s.logFile; $null }
        }
        $state.capturedLogFile | Should -Match 'test-run\.txt$'
        $state.capturedLogFile | Should -Match 'auto.testRuns.last'
    }

    It "uses -OutputDir directly instead of auto/testRuns" {
        $customDir = "$TestDrive/custom-runs"
        New-Item $customDir -ItemType Directory | Out-Null
        invokeHarness @{ OutputDir = $customDir }
        "$customDir/last" | Should -Exist
    }
}
