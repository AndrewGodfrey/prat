BeforeAll {
    Import-Module "$PSScriptRoot/PratBase/PratBase.psd1" -Force
    $scriptToTest = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $testCbDir = (Resolve-Path "$PSScriptRoot\..\pathbin\tests\testCb").Path
    $pratRoot   = (Resolve-Path "$testCbDir\..\..\..").Path
}

Describe "Invoke-CodebaseCommand" {
    BeforeEach {
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @("$pratRoot/codebaseProfile_prat.ps1") }
    }
    AfterEach { Pop-Location }

    It "Throws when called from an unknown project" {
        New-Item -Type Directory "TestDrive:\unknownProject" | Out-Null
        Push-Location "TestDrive:\unknownProject"
        { &$scriptToTest "build" } | Should -Throw "Unknown project*"
    }

    It "Throws with a junction-island hint when location matches a project only after resolving junctions" {
        $root = (Get-Item "TestDrive:\").FullName.TrimEnd('\')
        New-Item -ItemType Directory "$root/realrepo" -Force | Out-Null
        New-Item -ItemType Junction  "$root/junction" -Target "$root/realrepo" | Out-Null
        "@{ '.' = @{ repos = @{ repo = @{ root = '$root/junction' } } } }" | Out-File "$root/junction-profile.ps1"
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @("$root/junction-profile.ps1") }
        Push-Location "$root/realrepo"

        { &$scriptToTest "build" } | Should -Throw "*junction*"
    }

    It "Runs the project command script with its env delta applied" {
        Push-Location $testCbDir
        $result = &$scriptToTest "test" -CommandParameters @{NoCoverage=$true}
        $result | Should -Be "testCb: test: bar: NoCoverage=True"
    }

    It "Does not apply cachedEnvDelta for prebuild" {
        Push-Location $testCbDir
        $saved = $env:testenvvar
        $env:testenvvar = 'original'
        try {
            $result = &$scriptToTest "prebuild"
            $result | Should -Be "testCb: prebuild: original"
        } finally {
            $env:testenvvar = $saved
        }
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
        $tildePath    = "~/prat" + $testCbDir.Substring($pratRoot.Length)
        $expandedPath = (Resolve-Path $tildePath).Path
        $result = &$scriptToTest "test" -CommandParameters @{NoCoverage=$true; RepoRoot=$tildePath}
        $result | Should -Be "testCb: test: bar: NoCoverage=True RepoRoot=$expandedPath"
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

Describe "Resolve-EffectiveCommand" {
    BeforeAll {
        # Dot-source (with a dummy $CommandName, since it's mandatory) to load the function
        # without running the script's own dispatch body — guarded by its own InvocationName check.
        . $scriptToTest "build"
    }

    It "'test' always defers to Resolve-ProjectTestScript, which returns the project's own test outright" {
        function Resolve-ProjectTestScript { "explicit.ps1" }
        $project = @{ test = "explicit.ps1" }

        Resolve-EffectiveCommand "test" $project | Should -Be "explicit.ps1"
    }

    It "'test' returns whatever Resolve-ProjectTestScript resolves for a project with no test of its own" {
        function Resolve-ProjectTestScript { "detected.ps1" }
        $project = @{}

        Resolve-EffectiveCommand "test" $project | Should -Be "detected.ps1"
    }

    It "'test' returns null (NOP) when Resolve-ProjectTestScript finds nothing" {
        function Resolve-ProjectTestScript { $null }
        $project = @{}

        Resolve-EffectiveCommand "test" $project | Should -BeNullOrEmpty
    }

    It "doesn't consult Resolve-ProjectTestScript for non-test commands" {
        function Resolve-ProjectTestScript { throw "should not be called for build" }
        $project = @{ build = "build.ps1" }

        Resolve-EffectiveCommand "build" $project | Should -Be "build.ps1"
    }
}
