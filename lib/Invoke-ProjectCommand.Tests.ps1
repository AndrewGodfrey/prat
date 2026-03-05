BeforeAll {
    Import-Module "$PSScriptRoot/PratBase/PratBase.psd1" -Force
    $scriptToTest = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $testCbDir = (Resolve-Path "$PSScriptRoot\..\pathbin\tests\testCb").Path
    $pratRoot   = (Resolve-Path "$testCbDir\..\..\..").Path
}

Describe "Invoke-ProjectCommand" {
    BeforeEach {
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @("$pratRoot/repoProfile_prat.ps1") }
    }
    AfterEach { Pop-Location }

    It "Throws when called from an unknown project" {
        New-Item -Type Directory "TestDrive:\unknownProject" | Out-Null
        Push-Location "TestDrive:\unknownProject"
        { &$scriptToTest "build" } | Should -Throw "Unknown project*"
    }

    It "Runs the project command script with its env delta applied" {
        Push-Location $testCbDir
        $result = &$scriptToTest "test" -CommandParameters @{NoCoverage=$true}
        $result | Should -Be "testCb: test: bar: NoCoverage=True"
    }

    It "uses -RepoRoot from CommandParameters for project detection instead of pwd" {
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

    It "Runs the project deploy script" {
        Push-Location $testCbDir
        $result = &$scriptToTest "deploy"
        $result | Should -Be "testCb: deploy: bar"
    }

    It "Passes -Force to the project deploy script" {
        Push-Location $testCbDir
        $result = &$scriptToTest "deploy" -CommandParameters @{Force=$true}
        $result | Should -Be "testCb: deploy: bar: Force=True"
    }

    It "Does nothing when no script is defined for the command" {
        $testCbDirFwd = $testCbDir.Replace('\', '/')
        "@{ '.' = @{ repos = @{ nopTest = @{ root = `"$testCbDirFwd`" } } } }" |
            Out-File "TestDrive:\nop-profile.ps1"
        $profilePath = (Get-Item "TestDrive:\nop-profile.ps1").FullName.Replace('\', '/')
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @($profilePath) }
        Push-Location $testCbDir
        # nopTest has no command properties → NOP
        $result = &$scriptToTest "build"
        $result | Should -BeNull
    }

    It "Runs a command specified as a string script path" {
        $testDir = (Get-Item "TestDrive:\").FullName.TrimEnd('\').Replace('\', '/')
        $testCbDirFwd = $testCbDir.Replace('\', '/')
        "param(`$project, [hashtable]`$CommandParameters = @{}); 'string command ran'" |
            Out-File "TestDrive:\cmd.ps1"
        "@{ '.' = @{ repos = @{ strCmd = @{ root = `"$testCbDirFwd`"; test = `"$testDir/cmd.ps1`" } } } }" |
            Out-File "TestDrive:\profile.ps1"
        $profilePath = (Get-Item "TestDrive:\profile.ps1").FullName.Replace('\', '/')
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @($profilePath) }
        Push-Location $testCbDir
        $result = &$scriptToTest "test"
        $result | Should -Be "string command ran"
    }
}
