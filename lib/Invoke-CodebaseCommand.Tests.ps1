BeforeAll {
    Import-Module "$PSScriptRoot/PratBase/PratBase.psd1" -Force
    $scriptToTest = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $testCbDir = "$PSScriptRoot\..\pathbin\tests\testCb"
}

Describe "Invoke-CodebaseCommand" {
    AfterEach { Pop-Location }

    It "Throws when called from an unknown codebase" {
        New-Item -Type Directory "TestDrive:\unknownCodebase" | Out-Null
        Push-Location "TestDrive:\unknownCodebase"
        { &$scriptToTest "build" } | Should -Throw "Unknown codebase*"
    }

    It "Runs the codebase action script with its env delta applied" {
        Push-Location $testCbDir
        $result = &$scriptToTest "test" -CommandSwitches @{NoCoverage=$true}
        $result | Should -Be "testCb: test: bar"
    }

    It "uses -RepoRoot from CommandSwitches for codebase detection instead of pwd" {
        New-Item -Type Directory "TestDrive:\someOtherDir" | Out-Null
        Push-Location "TestDrive:\someOtherDir"
        $result = &$scriptToTest "test" -CommandSwitches @{NoCoverage=$true; RepoRoot=$testCbDir}
        $result | Should -Be "testCb: test: bar"
    }

    It "Runs the codebase deploy script" {
        Push-Location $testCbDir
        $result = &$scriptToTest "deploy"
        $result | Should -Be "testCb: deploy: bar"
    }

    It "Passes -Force to the codebase deploy script" {
        Push-Location $testCbDir
        $result = &$scriptToTest "deploy" -CommandSwitches @{Force=$true}
        $result | Should -Be "testCb: deploy: bar force"
    }

    It "Does nothing when no script is defined for the action" {
        Push-Location $testCbDir
        # Temporarily shadow Get-CodebaseScript to return null for this test
        function Get-CodebaseScript { return $null }
        $result = &$scriptToTest "build"
        $result | Should -BeNull
    }
}
