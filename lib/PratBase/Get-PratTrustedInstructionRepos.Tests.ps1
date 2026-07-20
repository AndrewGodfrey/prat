BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe "Get-PratTrustedInstructionRepos" {
    BeforeEach {
        $root = (Get-Item "TestDrive:\").FullName.TrimEnd('\').Replace('\', '/')
        $testProfilePath = "$root/codebaseProfile_test.ps1"
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @($testProfilePath) }
    }

    It "returns a trusted repo's root with the default instructionsFile" {
        "@{ '.' = @{ repos = @{ r = @{ trustAgentInstructions = `$true } } } }" | Out-File $testProfilePath

        $result = @(Get-PratTrustedInstructionRepos)

        $result.Count | Should -Be 1
        $result[0].root             | Should -Be "$root/r"
        $result[0].instructionsFile | Should -Be "AGENTS.md"
    }

    It "uses the repo's explicit agentInstructionsFile" {
        "@{ '.' = @{ repos = @{ r = @{ trustAgentInstructions = `$true; agentInstructionsFile = '.github/copilot-instructions.md' } } } }" | Out-File $testProfilePath

        $result = @(Get-PratTrustedInstructionRepos)

        $result[0].instructionsFile | Should -Be ".github/copilot-instructions.md"
    }

    It "excludes a repo with no trustAgentInstructions field" {
        "@{ '.' = @{ repos = @{ r = @{} } } }" | Out-File $testProfilePath

        $result = @(Get-PratTrustedInstructionRepos)

        $result.Count | Should -Be 0
    }

    It "excludes a repo with trustAgentInstructions explicitly false" {
        "@{ '.' = @{ repos = @{ r = @{ trustAgentInstructions = `$false } } } }" | Out-File $testProfilePath

        $result = @(Get-PratTrustedInstructionRepos)

        $result.Count | Should -Be 0
    }

    It "excludes a subproject's own entry even though it inherits trustAgentInstructions from its parent" {
        "@{ '.' = @{ repos = @{ r = @{ trustAgentInstructions = `$true; subprojects = @{ sub = @{ path = 'lib/sub' } } } } } }" | Out-File $testProfilePath

        $result = @(Get-PratTrustedInstructionRepos)

        $result.Count | Should -Be 1
        $result[0].root | Should -Be "$root/r"
    }

    It "aggregates multiple trusted repos, sorted by root" {
        "@{ '.' = @{ repos = @{ rB = @{ trustAgentInstructions = `$true }; rA = @{ trustAgentInstructions = `$true }; unset = @{} } } }" | Out-File $testProfilePath

        $result = @(Get-PratTrustedInstructionRepos)

        $result.Count      | Should -Be 2
        $result[0].root    | Should -Be "$root/rA"
        $result[1].root    | Should -Be "$root/rB"
    }

    It "returns an empty array when no repoProfile files are registered" {
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @() }

        $result = @(Get-PratTrustedInstructionRepos)

        $result.Count | Should -Be 0
    }
}
