BeforeAll {
    Import-Module "$PSScriptRoot/PratBase/PratBase.psd1" -Force
    $script:harness = "$PSScriptRoot/Invoke-TestWithSummary.ps1"

    # Minimal harness invocation with all required params.
    # Pass $extra to override individual params.
    function invokeHarness([hashtable] $extra = @{}) {
        $p = @{
            StartTime       = $extra.ContainsKey('StartTime')       ? $extra.StartTime       : [DateTimeOffset]::UtcNow
            RepoRoot        = $extra.ContainsKey('RepoRoot')        ? $extra.RepoRoot        : "$TestDrive/repo-$(New-Guid)"
            CoverageUnitForJaCoco = $extra.ContainsKey('CoverageUnitForJaCoco') ? $extra.CoverageUnitForJaCoco : ''
            InitialState    = $extra.ContainsKey('InitialState')    ? $extra.InitialState    : @{ failuresSeen = 0 }
            TestCommand     = $extra.ContainsKey('TestCommand')     ? $extra.TestCommand     : { }
            ProcessLine     = $extra.ContainsKey('ProcessLine')     ? $extra.ProcessLine     : { param($l, $s) $null }
            RenderResult    = $extra.ContainsKey('RenderResult')    ? $extra.RenderResult    : { param($s) }
            GetCoverageFile = $extra.ContainsKey('GetCoverageFile') ? $extra.GetCoverageFile : { param($rd) $null }
            GetTestResult   = $extra.ContainsKey('GetTestResult')   ? $extra.GetTestResult   : { param($s) @{ Passed = 3; Failed = 0; FatalError = $null } }
        }
        $p.OutputDir = $extra.ContainsKey('OutputDir') ? $extra.OutputDir : "$TestDrive/output-$(New-Guid)"
        if ($extra.ContainsKey('LogHeader'))     { $p.LogHeader     = $extra.LogHeader }
        if ($extra.ContainsKey('PassThru'))      { $p.PassThru      = $extra.PassThru }
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

    It "creates runDir under <OutputDir>/last" {
        $outputDir = "$TestDrive/repo-rundir"
        invokeHarness @{ OutputDir = $outputDir }
        "$outputDir/last" | Should -Exist
    }

    It "throws when -OutputDir is not supplied (no bare-root fallback)" {
        $p = @{
            StartTime       = [DateTimeOffset]::UtcNow
            RepoRoot        = "$TestDrive/repo-missing-outputdir"
            InitialState    = @{ failuresSeen = 0 }
            TestCommand     = { }
            ProcessLine     = { param($l, $s) $null }
            RenderResult    = { param($s) }
            GetCoverageFile = { param($rd) $null }
            GetTestResult   = { param($s) @{ Passed = 0; Failed = 0; FatalError = $null } }
        }
        { & $script:harness @p } | Should -Throw "*-OutputDir is required*"
    }

    It "writes LogHeader lines to test-run.txt" {
        $outputDir = "$TestDrive/repo-header"
        invokeHarness @{
            OutputDir = $outputDir
            LogHeader = @("RepoRoot: something", "TestArgs: foo.csproj", "")
        }
        $log = Get-Content "$outputDir/last/test-run.txt"
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
            CoverageUnitForJaCoco = ''
            GetCoverageFile = { param($rd) $covXml }
        }
        Should -Invoke Write-TestRunResult -Times 1 -ParameterFilter { $CoverageData.Pct -eq 90 }
    }

    It "injects state.logFile for use by ProcessLine" {
        $outputDir = "$TestDrive/repo-logfile"
        $state = @{ failuresSeen = 0 }
        invokeHarness @{
            OutputDir    = $outputDir
            InitialState = $state
            TestCommand  = { "hello" }
            ProcessLine  = { param($l, $s) $s.capturedLogFile = $s.logFile; $null }
        }
        $state.capturedLogFile | Should -Match 'test-run\.txt$'
        $state.capturedLogFile | Should -Match ([regex]::Escape($outputDir))
    }

    It "returns result object and skips Write-TestRunResult when -PassThru is set" {
        $covXml = "$TestDrive/cov-passthru.xml"
        @'
<?xml version="1.0"?>
<coverage line-rate="0.5" lines-covered="5" lines-valid="10">
  <packages><package name="p"><classes><class filename="F.cs"/></classes></package></packages>
</coverage>
'@ | Set-Content $covXml -Encoding utf8NoBOM

        $result = invokeHarness @{
            CoverageUnitForJaCoco = ''
            GetCoverageFile = { param($rd) $covXml }
            GetTestResult   = { param($s) @{ Passed = 3; Failed = 1; FatalError = $null } }
            PassThru        = $true
        }

        Should -Invoke Write-TestRunResult -Times 0
        $result.Passed           | Should -Be 3
        $result.Failed           | Should -Be 1
        $result.CoverageData.Covered   | Should -Be 5
        $result.CoverageData.Total     | Should -Be 10
        $result.CoverageData.Unit      | Should -Be "lines"
        $result.RunDir           | Should -Not -BeNullOrEmpty
    }

    It "returns only the result hashtable when -PassThru is set and ProcessLine emits live lines" {
        $result = invokeHarness @{
            TestCommand = { "FAILED test_one"; "FAILED test_two" }
            ProcessLine = { param($l, $s) $l.line }  # echo every line live, like failure reporting does
            PassThru    = $true
        }

        @($result).Count | Should -Be 1
        $result | Should -BeOfType [hashtable]
    }
}
