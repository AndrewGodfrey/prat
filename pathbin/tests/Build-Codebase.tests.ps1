BeforeAll {
    Import-Module "$PSScriptRoot/../../lib/PratBase/PratBase.psd1" -Force
    $script    = (Resolve-Path "$PSScriptRoot\..\Build-Codebase.ps1").Path
    $testCbDir = (Resolve-Path "$PSScriptRoot\testCb").Path
    $pratRoot  = (Resolve-Path "$PSScriptRoot\..\..").Path
}

Describe "Build-Codebase" {
    BeforeEach {
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @("$pratRoot/codebaseProfile_prat.ps1") }
    }
    AfterEach { Pop-Location }

    Context "absolute path arg" {
        It "Derives project from absolute root path without requiring CWD in testCb" {
            New-Item -Type Directory "TestDrive:\build-abs-root" | Out-Null
            Push-Location "TestDrive:\build-abs-root"
            $result = & $script $testCbDir
            $result | Should -Be "testCb: build: bar: Command=build RepoRoot=$testCbDir"
        }

        It "Accepts absolute subdir path for partial build" {
            New-Item -Type Directory "TestDrive:\build-abs-subdir" | Out-Null
            Push-Location "TestDrive:\build-abs-subdir"
            $result = & $script "$testCbDir\subdir"
            $result | Should -Be "testCb: build: bar: Command=build RepoRoot=$testCbDir\subdir"
        }
    }
}
