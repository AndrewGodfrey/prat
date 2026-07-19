BeforeDiscovery {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe "Get-PratRepoEntry" {
    It "returns the full index entry for a registered id" {
        InModuleScope PratBase {
            Mock Get-RepoProfileFiles { @('dummy') }
            Mock Get-PratRepoIndex { @{ repos = @{ myrepo = @{ id = 'myrepo'; root = 'C:/x/myrepo'; gitRemotes = @{ origin = 'https://example.com/x.git' } } } } }

            $result = Get-PratRepoEntry 'myrepo'

            $result.root | Should -Be 'C:/x/myrepo'
            $result.gitRemotes.origin | Should -Be 'https://example.com/x.git'
        }
    }

    It "returns null for an unregistered id" {
        InModuleScope PratBase {
            Mock Get-RepoProfileFiles { @('dummy') }
            Mock Get-PratRepoIndex { @{ repos = @{ myrepo = @{ root = 'C:/x/myrepo' } } } }
            Get-PratRepoEntry 'ghost' | Should -BeNullOrEmpty
        }
    }

    It "returns null when there is no repo index" {
        InModuleScope PratBase {
            Mock Get-RepoProfileFiles { @('dummy') }
            Mock Get-PratRepoIndex { $null }
            Get-PratRepoEntry 'anything' | Should -BeNullOrEmpty
        }
    }
}
