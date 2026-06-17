BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    . $PSScriptRoot\instFilesAndFolders.ps1

    Import-Module "$PSScriptRoot\..\TextFileEditor\TextFileEditor.psd1"
    Import-Module "$PSScriptRoot\..\PratBase\PratBase.psd1"

    class MockStage {
        [int] $changeCount = 0
        [void] OnChange() { $this.changeCount++ }
    }
}

Describe "ConvertTo-CopilotEvent" {
    It "maps TurnCompleted to Stop" {
        ConvertTo-CopilotEvent 'TurnCompleted' | Should -Be 'Stop'
    }

    It "returns null for PromptSubmitted (no Copilot equivalent)" {
        ConvertTo-CopilotEvent 'PromptSubmitted' | Should -BeNullOrEmpty
    }

    It "returns null for unrecognized events" {
        ConvertTo-CopilotEvent 'SomeOtherEvent' | Should -BeNullOrEmpty
    }
}

Describe "ConvertTo-CopilotHook" {
    It "sets type to command" {
        $result = ConvertTo-CopilotHook @{ Script = '$home/prat/lib/On-Foo.ps1' }
        $result.type | Should -Be 'command'
    }

    It "produces powershell property wrapping the script path in quotes" {
        $result = ConvertTo-CopilotHook @{ Script = '$home/prat/lib/On-Foo.ps1' }
        $result.powershell | Should -Be '& "$home/prat/lib/On-Foo.ps1"'
    }

    It "sets timeoutSec to 15" {
        $result = ConvertTo-CopilotHook @{ Script = '$home/prat/lib/On-Foo.ps1' }
        $result.timeoutSec | Should -Be 15
    }
}

Describe "Merge-AgentHooksToCopilot" {
    It "returns empty when given an empty list" {
        $result = Merge-AgentHooksToCopilot @()
        $result.Count | Should -Be 0
    }

    It "returns empty when all events have no Copilot equivalent" {
        $specs = @(@{ PromptSubmitted = @{ Script = '$home/prat/lib/On-Foo.ps1' } })
        $result = Merge-AgentHooksToCopilot $specs
        $result.Count | Should -Be 0
    }

    It "maps TurnCompleted to Stop event" {
        $specs = @(@{ TurnCompleted = @{ Script = '$home/prat/lib/On-AgentTurnCompleted.ps1' } })
        $result = Merge-AgentHooksToCopilot $specs
        $result['Stop'] | Should -Not -BeNullOrEmpty
    }

    It "merges TurnCompleted hooks from multiple layers into one Stop array" {
        $specs = @(
            @{ TurnCompleted = @{ Script = '$home/prat/lib/On-AgentTurnCompleted.ps1' } }
            @{ TurnCompleted = @{ Script = '$home/prefs/lib/On-Extra.ps1' } }
        )
        $result = Merge-AgentHooksToCopilot $specs
        @($result['Stop']).Count | Should -Be 2
    }
}

Describe "Install-CopilotHooks" {
    BeforeEach {
        $script:testDir = ((Get-Item "TestDrive:\").FullName -replace '\\', '/').TrimEnd('/')
        $script:copilotDir = "$script:testDir/.copilot"
        $script:hooksDir = "$script:copilotDir/hooks"
        $script:destFile = "$script:hooksDir/prat-hooks.json"
        $script:stage = [MockStage]::new()
        $script:hooksScript = "$script:testDir/Get-AgentHooks.ps1"
        'return @{ TurnCompleted = @{ Script = "$home/prat/lib/On-AgentTurnCompleted.ps1" } }' |
            Out-File $script:hooksScript -Encoding utf8NoBOM
        Mock Resolve-PratLibFile { @($script:hooksScript) }
    }

    It "creates prat-hooks.json with Stop event from TurnCompleted" {
        Install-CopilotHooks $script:stage $script:copilotDir

        $json = Get-Content $script:destFile -Raw | ConvertFrom-Json
        $json.hooks.Stop | Should -Not -BeNullOrEmpty
    }

    It "sets prat-hooks.json read-only" {
        Install-CopilotHooks $script:stage $script:copilotDir

        (Get-ItemProperty $script:destFile).IsReadOnly | Should -BeTrue
    }
}
