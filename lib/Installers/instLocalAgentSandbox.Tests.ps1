BeforeDiscovery {
    Import-Module "$PSScriptRoot/Installers.psd1" -Force
}

Describe "Get-AgentGitconfigContent" {
    BeforeAll {
        Import-Module "$PSScriptRoot/Installers.psd1" -Force
    }

    It "includes [safe] entries for each directory" {
        InModuleScope Installers {
            $result = Get-AgentGitconfigContent @("C:\Users\andrew\de", "C:\Users\andrew\prat")

            $result | Should -Match "\[safe\]"
            $result | Should -Match "directory = C:/Users/andrew/de"
            $result | Should -Match "directory = C:/Users/andrew/prat"
        }
    }

    It "includes [credential] section with empty helper to suppress auth dialogs" {
        InModuleScope Installers {
            $result = Get-AgentGitconfigContent @("C:\Users\andrew\de")

            $result | Should -Match "\[credential\]"
            $result | Should -Match "helper\s*="
        }
    }

    It "includes [user] section with a commit identity" {
        InModuleScope Installers {
            $result = Get-AgentGitconfigContent @("C:\Users\andrew\de")

            $result | Should -Match "\[user\]"
            $result | Should -Match "name\s*="
            $result | Should -Match "email\s*="
        }
    }

    It "converts backslashes to forward slashes" {
        InModuleScope Installers {
            $result = Get-AgentGitconfigContent @("C:\path\with\backslashes")
            $result | Should -Match "directory = C:/path/with/backslashes"
        }
    }

    It "does not double-convert forward slashes" {
        InModuleScope Installers {
            $result = Get-AgentGitconfigContent @("C:/already/forward")
            $result | Should -Match "directory = C:/already/forward"
        }
    }
}
