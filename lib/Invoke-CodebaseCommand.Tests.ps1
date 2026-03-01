BeforeAll {
    Import-Module "$PSScriptRoot/PratBase/PratBase.psd1" -Force
    $scriptToTest = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $testCbDir = (Resolve-Path "$PSScriptRoot\..\pathbin\tests\testCb").Path
}

Describe "Invoke-CodebaseCommand" {
    AfterEach { Pop-Location }

    It "Throws when called from an unknown codebase" {
        New-Item -Type Directory "TestDrive:\unknownCodebase" | Out-Null
        Push-Location "TestDrive:\unknownCodebase"
        { &$scriptToTest "build" } | Should -Throw "Unknown codebase*"
    }

    It "Runs the codebase command script with its env delta applied" {
        Push-Location $testCbDir
        $result = &$scriptToTest "test" -CommandParameters @{NoCoverage=$true}
        $result | Should -Be "testCb: test: bar: NoCoverage=True"
    }

    It "uses -RepoRoot from CommandParameters for codebase detection instead of pwd" {
        New-Item -Type Directory "TestDrive:\someOtherDir" | Out-Null
        Push-Location "TestDrive:\someOtherDir"
        $result = &$scriptToTest "test" -CommandParameters @{NoCoverage=$true; RepoRoot=$testCbDir}
        $result | Should -Be "testCb: test: bar: NoCoverage=True RepoRoot=$testCbDir"
    }

    It "resolves ~ in RepoRoot from CommandParameters" {
        New-Item -Type Directory "TestDrive:\someOtherDir2" | Out-Null
        Push-Location "TestDrive:\someOtherDir2"
        $tildePath = "~" + $testCbDir.Substring($HOME.Length)
        $result = &$scriptToTest "test" -CommandParameters @{NoCoverage=$true; RepoRoot=$tildePath}
        $result | Should -Be "testCb: test: bar: NoCoverage=True RepoRoot=$testCbDir"
    }

    It "Runs the codebase deploy script" {
        Push-Location $testCbDir
        $result = &$scriptToTest "deploy"
        $result | Should -Be "testCb: deploy: bar"
    }

    It "Passes -Force to the codebase deploy script" {
        Push-Location $testCbDir
        $result = &$scriptToTest "deploy" -CommandParameters @{Force=$true}
        $result | Should -Be "testCb: deploy: bar: Force=True"
    }

    It "Does nothing when no script is defined for the command" {
        Push-Location $testCbDir
        # Temporarily shadow Get-CodebaseScript to return null for this test
        function Get-CodebaseScript { return $null }
        $result = &$scriptToTest "build"
        $result | Should -BeNull
    }
}
