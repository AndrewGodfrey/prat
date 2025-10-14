Describe "Update-DevEnvironment" {
    BeforeEach {
        Mock Write-Host {}
        function git($command){}
        Mock git -Verifiable {
            if ($command -ne "pull") { throw "Unexpected git command: $command" }
        }

        function Deploy-Codebase {}
        Mock Deploy-Codebase -Verifiable {}

        $simulateDeDoesNotExist = $false
        function Set-LocationUsingShortcut($shortcut) {}
        Mock Set-LocationUsingShortcut -Verifiable {
            if ($shortcut -eq "de" -and $simulateDeDoesNotExist) {
                throw "Shortcut 'de' does not exist"
            }
        }
    }
    It "Pulls and deploys prat and de" {
        Update-DevEnvironment 

        Should -Invoke -Command Set-LocationUsingShortcut -Exactly 2
        Should -Invoke -Command git -Exactly 2
        Should -Invoke -Command Deploy-Codebase -Exactly 2
    }
    It "Works if de doesn't exist" {
        $simulateDeDoesNotExist = $true

        Update-DevEnvironment 

        Should -Invoke -Command Set-LocationUsingShortcut -Exactly 2
        Should -Invoke -Command git -Exactly 1
        Should -Invoke -Command Deploy-Codebase -Exactly 1
    }
}
