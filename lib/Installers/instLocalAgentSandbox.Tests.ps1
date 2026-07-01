BeforeDiscovery {
    Import-Module "$PSScriptRoot/Installers.psd1" -Force
}

Describe "Install-LocalAgentSandbox" {
    BeforeAll {
        Import-Module "$PSScriptRoot/Installers.psd1" -Force
        # Stub for external command not available in test environment
        function global:Invoke-Gsudo([scriptblock]$ScriptBlock) {}
    }

    Context "NTFS grant ordering" {
        It "applies roPaths grants before rwPaths so rwPaths wins on overlap" {
            InModuleScope Installers {
                $stage = [PSCustomObject]@{}
                $stage | Add-Member ScriptMethod GetIsStepComplete { $false }
                $stage | Add-Member ScriptMethod OnChange {}
                $stage | Add-Member ScriptMethod SetStepComplete {}

                $callOrder = [System.Collections.Generic.List[string]]::new()
                Mock applyPathGrants    { $callOrder.Add($permission) }
                Mock Get-LocalUser      { [PSCustomObject]@{} }
                Mock Test-Path          { $true }
                Mock Invoke-Gsudo       {}
                Mock Install-TextToFile {}

                Install-LocalAgentSandbox $stage -agentUser 'test_agent' `
                    -rwPaths @('C:\test\rw') -roPaths @('C:\test\ro')

                $callOrder | Should -Be @('RX', 'F')
            }
        }
    }

    Context "Ancestor traverse grants" {
        It "grants ancestor access on the deduped parent of every rw/ro path" {
            InModuleScope Installers {
                $stage = [PSCustomObject]@{}
                $stage | Add-Member ScriptMethod GetIsStepComplete { $false }
                $stage | Add-Member ScriptMethod OnChange {}
                $stage | Add-Member ScriptMethod SetStepComplete {}

                $grantedDirs = [System.Collections.Generic.List[string]]::new()
                Mock applyAncestorTraverseGrants { $grantedDirs.AddRange([string[]]$paths) }
                Mock Get-LocalUser      { [PSCustomObject]@{} }
                Mock Test-Path          { $true }
                Mock Invoke-Gsudo       {}
                Mock Install-TextToFile {}

                Install-LocalAgentSandbox $stage -agentUser 'test_agent' `
                    -rwPaths @('C:\parent\de', 'C:\parent\prat') -roPaths @('C:\parent\prefs')

                ($grantedDirs | Sort-Object) | Should -Be @('C:\parent\de', 'C:\parent\prat', 'C:\parent\prefs')
            }
        }

        It "dedupes ancestors that share the same parent directory" {
            InModuleScope Installers {
                Mock Invoke-Gsudo {}

                applyAncestorTraverseGrants 'test_agent' @('C:\parent\de', 'C:\parent\prat')

                Should -Invoke Invoke-Gsudo -Times 1 -Exactly
            }
        }

        It "throws instead of granting on a drive root when given a shallow path" {
            InModuleScope Installers {
                Mock Invoke-Gsudo {}

                { applyAncestorTraverseGrants 'test_agent' @('C:\rw') } | Should -Throw '*drive root*'

                Should -Invoke Invoke-Gsudo -Times 0 -Exactly
            }
        }
    }
}

Describe "Get-SshdConfigContent" {
    BeforeAll {
        Import-Module "$PSScriptRoot/Installers.psd1" -Force
    }

    It "restricts listening to loopback only" {
        InModuleScope Installers {
            Get-SshdConfigContent | Should -Match "ListenAddress 127\.0\.0\.1"
        }
    }

    It "enables pubkey authentication" {
        InModuleScope Installers {
            Get-SshdConfigContent | Should -Match "PubkeyAuthentication yes"
        }
    }

    It "disables password authentication" {
        InModuleScope Installers {
            Get-SshdConfigContent | Should -Match "PasswordAuthentication no"
        }
    }
}

Describe "Get-AgentGitconfigContent" {
    BeforeAll {
        Import-Module "$PSScriptRoot/Installers.psd1" -Force
    }

    It "includes [safe] entries for each directory" {
        InModuleScope Installers {
            $result = Get-AgentGitconfigContent @("C:\Users\xyz\de", "C:\Users\xyz\prat")

            $result | Should -Match "\[safe\]"
            $result | Should -Match "directory = C:/Users/xyz/de"
            $result | Should -Match "directory = C:/Users/xyz/prat"
        }
    }

    It "includes [credential] section with empty helper to suppress auth dialogs" {
        InModuleScope Installers {
            $result = Get-AgentGitconfigContent @("C:\Users\xyz\de")

            $result | Should -Match "\[credential\]"
            $result | Should -Match "helper\s*="
        }
    }

    It "includes [user] section with a commit identity" {
        InModuleScope Installers {
            $result = Get-AgentGitconfigContent @("C:\Users\xyz\de")

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
