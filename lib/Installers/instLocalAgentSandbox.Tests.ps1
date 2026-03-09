BeforeDiscovery {
    Import-Module "$PSScriptRoot/Installers.psd1" -Force
}

Describe "Get-AgentGitconfigContent" {
    BeforeAll {
        Import-Module "$PSScriptRoot/Installers.psd1" -Force
    }

    It "produces a [safe] section with one directory" {
        InModuleScope Installers {
            $result = Get-AgentGitconfigContent @("C:\Users\andrew\de")
            $result | Should -Be "[safe]`n`tdirectory = C:/Users/andrew/de`n"
        }
    }

    It "produces a [safe] section with multiple directories" {
        InModuleScope Installers {
            $result = Get-AgentGitconfigContent @("C:\Users\andrew\de", "C:\Users\andrew\prat")
            $result | Should -Be "[safe]`n`tdirectory = C:/Users/andrew/de`n`tdirectory = C:/Users/andrew/prat`n"
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
