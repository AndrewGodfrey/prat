BeforeAll {
    Import-Module "$PSScriptRoot/../../lib/PratBase/PratBase.psd1" -Force
    $script    = (Resolve-Path "$PSScriptRoot\..\Test-Codebase.ps1").Path
    $testCbDir = (Resolve-Path "$PSScriptRoot\testCb").Path
    $pratRoot  = (Resolve-Path "$PSScriptRoot\..\..").Path
}

Describe "Test-Codebase" {
    BeforeEach {
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @("$pratRoot/codebaseProfile_prat.ps1") }
    }
    AfterEach { Pop-Location }

    It "Derives RepoRoot from absolute Focus path, without requiring -RepoRoot" {
        $absoluteTestCbFile = "$testCbDir\testCb_fileWithTests.ps1"
        New-Item -Type Directory "TestDrive:\abs-focus-test" | Out-Null
        Push-Location "TestDrive:\abs-focus-test"
        $result = & $script $absoluteTestCbFile -NoCoverage
        $result | Should -Be "testCb: test: bar: Focus=$absoluteTestCbFile NoCoverage=True RepoRoot=$testCbDir"
    }

    It "Relative Focus uses CWD for project detection" {
        Push-Location $testCbDir
        $result = & $script "testCb_fileWithTests.ps1" -NoCoverage
        $result | Should -Be "testCb: test: bar: Focus=testCb_fileWithTests.ps1 NoCoverage=True"
    }

    It "Absolute directory Focus runs full suite" {
        New-Item -Type Directory "TestDrive:\abs-dir-test" | Out-Null
        Push-Location "TestDrive:\abs-dir-test"
        $result = & $script $testCbDir -NoCoverage
        $result | Should -Be "testCb: test: bar: Focus=$testCbDir NoCoverage=True RepoRoot=$testCbDir"
    }
}
