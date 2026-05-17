BeforeAll {
    Import-Module "$PSScriptRoot/../../lib/PratBase/PratBase.psd1" -Force
    $script    = (Resolve-Path "$PSScriptRoot\..\Prebuild-Codebase.ps1").Path
    $testCbDir = (Resolve-Path "$PSScriptRoot\testCb").Path
    $pratRoot  = (Resolve-Path "$PSScriptRoot\..\..").Path
}

Describe "Prebuild-Codebase" {
    BeforeEach {
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @("$pratRoot/codebaseProfile_prat.ps1") }
    }
    AfterEach { Pop-Location }

    Context "absolute path arg" {
        It "Derives project from absolute root path without requiring CWD in testCb" {
            New-Item -Type Directory "TestDrive:\prebuild-abs-root" | Out-Null
            Push-Location "TestDrive:\prebuild-abs-root"
            $saved = $env:testenvvar
            $env:testenvvar = $null  # prebuild skips cachedEnvDelta; guard against prior test leaving it set
            try {
                $result = & $script $testCbDir
                $result | Should -Be "testCb: prebuild: : Force=False RepoRoot=$testCbDir"
            } finally {
                $env:testenvvar = $saved
            }
        }

        It "Throws when path is an absolute subdirectory" {
            Push-Location $testCbDir
            { & $script "$testCbDir\subdir" } | Should -Throw "Path must be the project root*"
        }

        It "Throws when path is relative" {
            Push-Location $testCbDir
            { & $script "subdir" } | Should -Throw "Path must be absolute*"
        }

        It "Throws when path is not a registered project root" {
            New-Item -Type Directory "TestDrive:\prebuild-unreg" | Out-Null
            $unreg = (Get-Item "TestDrive:\prebuild-unreg").FullName
            Push-Location $unreg
            { & $script $unreg } | Should -Throw "Not a registered project root*"
        }
    }
}
