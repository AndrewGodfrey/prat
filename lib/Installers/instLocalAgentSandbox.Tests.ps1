BeforeDiscovery {
    Import-Module "$PSScriptRoot/Installers.psd1" -Force
}

Describe "Install-LocalAgentSandbox" {
    BeforeAll {
        Import-Module "$PSScriptRoot/Installers.psd1" -Force
        # Stub for external command not available in test environment
        function global:Invoke-Gsudo([scriptblock]$ScriptBlock) {}
    }

    Context "Spec-driven NTFS grants" {
        # Each test builds a $stage stub whose GetIsStepComplete is always true, so the one-time and
        # home-setup blocks are skipped and only the ACL spec-diff block runs. GetStepState returns the
        # saved spec text; SetStepState captures what gets saved into $stage.Written.
        BeforeAll {
            $script:newAclStage = {
                param([string] $savedSpecText)
                $s = [PSCustomObject]@{ Saved = $savedSpecText; Written = $null }
                $s | Add-Member ScriptMethod GetIsStepComplete { param($id) $true }
                $s | Add-Member ScriptMethod GetStepState      { param($id) $this.Saved }
                $s | Add-Member ScriptMethod SetStepState      { param($id, $v) $this.Written = $v }
                $s | Add-Member ScriptMethod OnChange          {}
                return $s
            }
        }

        It "on first run (no saved spec) grants every desired path, parent before child" {
            $stage = & $newAclStage $null
            InModuleScope Installers -Parameters @{ stage = $stage } {
                param($stage)
                $calls = [System.Collections.Generic.List[string]]::new()
                Mock applyPathGrants            { $calls.Add("$permission $($paths -join ',')") }
                Mock applyAncestorTraverseGrants {}
                Mock revokePathGrant           {}

                Install-LocalAgentSandbox $stage -agentUser 'a' -rwPaths @('C:\p\child') -roPaths @('C:\p')

                $calls | Should -Be @('RX c:\p', 'F c:\p\child')
            }
        }

        It "revokes a root that dropped out of the spec" {
            $saved = InModuleScope Installers { Format-AgentAclSpec (Get-AgentAclSpec -rwPaths @('C:\keep', 'C:\drop') -roPaths @()) }
            $stage = & $newAclStage $saved
            InModuleScope Installers -Parameters @{ stage = $stage } {
                param($stage)
                $revoked = [System.Collections.Generic.List[string]]::new()
                Mock revokePathGrant           { $revoked.Add($path) }
                Mock applyPathGrants           {}
                Mock applyAncestorTraverseGrants {}

                Install-LocalAgentSandbox $stage -agentUser 'a' -rwPaths @('C:\keep') -roPaths @()

                $revoked | Should -Be @('c:\drop')
                Should -Invoke applyPathGrants -Times 0 -Exactly
            }
        }

        It "makes no grant/revoke calls and saves nothing when the spec is unchanged" {
            $saved = InModuleScope Installers { Format-AgentAclSpec (Get-AgentAclSpec -rwPaths @('C:\a') -roPaths @()) }
            $stage = & $newAclStage $saved
            InModuleScope Installers -Parameters @{ stage = $stage } {
                param($stage)
                Mock applyPathGrants           {}
                Mock revokePathGrant           {}
                Mock applyAncestorTraverseGrants {}

                Install-LocalAgentSandbox $stage -agentUser 'a' -rwPaths @('C:\a') -roPaths @()

                Should -Invoke applyPathGrants -Times 0 -Exactly
                Should -Invoke revokePathGrant -Times 0 -Exactly
                $stage.Written | Should -BeNull
            }
        }

        It "saves the desired spec after applying" {
            $stage = & $newAclStage $null
            $expected = InModuleScope Installers { Format-AgentAclSpec (Get-AgentAclSpec -rwPaths @('C:\a') -roPaths @('C:\b')) }
            InModuleScope Installers -Parameters @{ stage = $stage } {
                param($stage)
                Mock applyPathGrants           {}
                Mock revokePathGrant           {}
                Mock applyAncestorTraverseGrants {}

                Install-LocalAgentSandbox $stage -agentUser 'a' -rwPaths @('C:\a') -roPaths @('C:\b')
            }
            $stage.Written | Should -BeExactly $expected
        }
    }

    Context "Ancestor traverse grants" {
        It "grants ancestor-traverse access for the applied paths" {
            InModuleScope Installers {
                $stage = [PSCustomObject]@{ Saved = $null; Written = $null }
                $stage | Add-Member ScriptMethod GetIsStepComplete { param($id) $true }
                $stage | Add-Member ScriptMethod GetStepState      { param($id) $this.Saved }
                $stage | Add-Member ScriptMethod SetStepState      { param($id, $v) $this.Written = $v }
                $stage | Add-Member ScriptMethod OnChange          {}

                $grantedDirs = [System.Collections.Generic.List[string]]::new()
                Mock applyAncestorTraverseGrants { $grantedDirs.AddRange([string[]]$paths) }
                Mock applyPathGrants {}
                Mock revokePathGrant {}

                Install-LocalAgentSandbox $stage -agentUser 'test_agent' `
                    -rwPaths @('C:\parent\de', 'C:\parent\prat') -roPaths @('C:\parent\prefs')

                ($grantedDirs | Sort-Object) | Should -Be @('c:\parent\de', 'c:\parent\prat', 'c:\parent\prefs')
            }
        }

        It "dedupes ancestors that share the same parent directory" {
            InModuleScope Installers {
                Mock Invoke-Gsudo {}

                applyAncestorTraverseGrants 'test_agent' @('C:\parent\de', 'C:\parent\prat')

                Should -Invoke Invoke-Gsudo -Times 1 -Exactly
            }
        }

        It "skips (without throwing or warning) an ancestor that resolves to a drive root" {
            InModuleScope Installers {
                Mock Invoke-Gsudo {}
                Mock Write-Warning {}

                { applyAncestorTraverseGrants 'test_agent' @('C:\rw') } | Should -Not -Throw

                Should -Invoke Invoke-Gsudo -Times 0 -Exactly
                Should -Invoke Write-Warning -Times 0 -Exactly
            }
        }

        It "still grants ancestor access for other paths in the same call when one resolves to a drive root" {
            InModuleScope Installers {
                Mock Invoke-Gsudo {}
                Mock Write-Warning {}

                applyAncestorTraverseGrants 'test_agent' @('C:\rw', 'C:\parent\de')

                Should -Invoke Invoke-Gsudo -Times 1 -Exactly
            }
        }
    }
}

Describe "Get-CanonicalAclPath" {
    BeforeAll { Import-Module "$PSScriptRoot/Installers.psd1" -Force }

    It "lowercases the path (case-insensitive matching, mirroring the permission hook)" {
        InModuleScope Installers {
            Get-CanonicalAclPath 'C:\Users\Me\MyRepo' | Should -BeExactly 'c:\users\me\myrepo'
        }
    }

    It "collapses . and .. segments" {
        InModuleScope Installers {
            Get-CanonicalAclPath 'C:\a\b\..\c\.\d' | Should -BeExactly 'c:\a\c\d'
        }
    }

    It "normalizes forward slashes to backslashes" {
        InModuleScope Installers {
            Get-CanonicalAclPath 'C:/Users/me/myrepo' | Should -BeExactly 'c:\users\me\myrepo'
        }
    }

    It "trims a trailing separator" {
        InModuleScope Installers {
            Get-CanonicalAclPath 'C:\a\b\' | Should -BeExactly 'c:\a\b'
        }
    }
}

Describe "Get-AgentAclSpec" {
    BeforeAll { Import-Module "$PSScriptRoot/Installers.psd1" -Force }

    It "tags rwPaths as rw and roPaths as ro" {
        InModuleScope Installers {
            $spec = Get-AgentAclSpec -rwPaths @('C:\a\rw') -roPaths @('C:\a\ro')
            ($spec | Where-Object Path -eq 'c:\a\rw').Access | Should -Be 'rw'
            ($spec | Where-Object Path -eq 'c:\a\ro').Access | Should -Be 'ro'
        }
    }

    It "canonicalizes the paths" {
        InModuleScope Installers {
            $spec = Get-AgentAclSpec -rwPaths @('C:/A/RW') -roPaths @()
            $spec.Path | Should -Be 'c:\a\rw'
        }
    }

    It "sorts ascending by path so a parent precedes its children" {
        InModuleScope Installers {
            $spec = Get-AgentAclSpec -rwPaths @('C:\a\b\c', 'C:\a', 'C:\a\b') -roPaths @()
            $spec.Path | Should -Be @('c:\a', 'c:\a\b', 'c:\a\b\c')
        }
    }

    It "dedupes an exact-duplicate path, with rw winning over ro" {
        InModuleScope Installers {
            $spec = Get-AgentAclSpec -rwPaths @('C:\a\dup') -roPaths @('C:\a\dup')
            @($spec).Count | Should -Be 1
            $spec.Access | Should -Be 'rw'
        }
    }
}

Describe "AclSpec serialization round-trip" {
    BeforeAll { Import-Module "$PSScriptRoot/Installers.psd1" -Force }

    It "Format then ConvertFrom yields the original spec" {
        InModuleScope Installers {
            $spec = Get-AgentAclSpec -rwPaths @('C:\a\rw') -roPaths @('C:\a\ro')
            $round = ConvertFrom-AgentAclSpecText (Format-AgentAclSpec $spec)
            ($round | ForEach-Object { "$($_.Access) $($_.Path)" }) |
                Should -Be ($spec | ForEach-Object { "$($_.Access) $($_.Path)" })
        }
    }
}

Describe "Compare-AgentAclSpec" {
    BeforeAll { Import-Module "$PSScriptRoot/Installers.psd1" -Force }

    It "puts a new desired path into Apply" {
        InModuleScope Installers {
            $saved   = Get-AgentAclSpec -rwPaths @('C:\a') -roPaths @()
            $desired = Get-AgentAclSpec -rwPaths @('C:\a', 'C:\b') -roPaths @()
            $delta = Compare-AgentAclSpec -Saved $saved -Desired $desired
            $delta.Apply.Path  | Should -Be 'c:\b'
            @($delta.Revoke).Count | Should -Be 0
        }
    }

    It "puts a changed-access path (ro->rw) into Apply" {
        InModuleScope Installers {
            $saved   = Get-AgentAclSpec -rwPaths @()        -roPaths @('C:\a')
            $desired = Get-AgentAclSpec -rwPaths @('C:\a')  -roPaths @()
            $delta = Compare-AgentAclSpec -Saved $saved -Desired $desired
            $delta.Apply.Path   | Should -Be 'c:\a'
            $delta.Apply.Access | Should -Be 'rw'
        }
    }

    It "leaves an unchanged entry out of both Apply and Revoke" {
        InModuleScope Installers {
            $spec = Get-AgentAclSpec -rwPaths @('C:\a') -roPaths @()
            $delta = Compare-AgentAclSpec -Saved $spec -Desired $spec
            @($delta.Apply).Count  | Should -Be 0
            @($delta.Revoke).Count | Should -Be 0
        }
    }

    It "puts a dropped path into Revoke" {
        InModuleScope Installers {
            $saved   = Get-AgentAclSpec -rwPaths @('C:\a', 'C:\b') -roPaths @()
            $desired = Get-AgentAclSpec -rwPaths @('C:\a')         -roPaths @()
            $delta = Compare-AgentAclSpec -Saved $saved -Desired $desired
            $delta.Revoke | Should -Be 'c:\b'
        }
    }

    It "revokes only the outermost of two dropped roots where one nests in the other" {
        InModuleScope Installers {
            $saved   = Get-AgentAclSpec -rwPaths @('C:\a', 'C:\a\child') -roPaths @()
            $desired = Get-AgentAclSpec -rwPaths @()                     -roPaths @()
            $delta = Compare-AgentAclSpec -Saved $saved -Desired $desired
            $delta.Revoke | Should -Be 'c:\a'
        }
    }

    It "treats a null saved spec (first-ever run) as empty, applying everything" {
        InModuleScope Installers {
            $desired = Get-AgentAclSpec -rwPaths @('C:\a') -roPaths @('C:\b')
            $delta = Compare-AgentAclSpec -Saved $null -Desired $desired
            @($delta.Apply).Count  | Should -Be 2
            @($delta.Revoke).Count | Should -Be 0
        }
    }

    It "handles an empty desired spec (all saved grants revoked)" {
        InModuleScope Installers {
            $saved = Get-AgentAclSpec -rwPaths @('C:\a') -roPaths @()
            $delta = Compare-AgentAclSpec -Saved $saved -Desired @()
            @($delta.Apply).Count | Should -Be 0
            $delta.Revoke | Should -Be 'c:\a'
        }
    }

    It "revokes a dropped child that nests under a surviving root" {
        InModuleScope Installers {
            $saved   = Get-AgentAclSpec -rwPaths @('C:\a', 'C:\a\child') -roPaths @()
            $desired = Get-AgentAclSpec -rwPaths @('C:\a')               -roPaths @()
            $delta = Compare-AgentAclSpec -Saved $saved -Desired $desired
            $delta.Revoke | Should -Be 'c:\a\child'
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
