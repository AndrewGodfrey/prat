BeforeDiscovery {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe "Get-PratRepoRoot" {
    It "returns the root for a registered id" {
        InModuleScope PratBase {
            Mock Get-RepoProfileFiles { @('dummy') }
            Mock Get-PratRepoIndex { @{ repos = @{ myrepo = @{ id = 'myrepo'; root = 'C:/x/myrepo' } } } }
            Get-PratRepoRoot 'myrepo' | Should -Be 'C:/x/myrepo'
        }
    }

    It "returns null for an unregistered id" {
        InModuleScope PratBase {
            Mock Get-RepoProfileFiles { @('dummy') }
            Mock Get-PratRepoIndex { @{ repos = @{ myrepo = @{ root = 'C:/x/myrepo' } } } }
            Get-PratRepoRoot 'ghost' | Should -BeNullOrEmpty
        }
    }

    It "returns null when there is no repo index" {
        InModuleScope PratBase {
            Mock Get-RepoProfileFiles { @('dummy') }
            Mock Get-PratRepoIndex { $null }
            Get-PratRepoRoot 'anything' | Should -BeNullOrEmpty
        }
    }
}
