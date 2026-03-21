Describe "Update-DevEnvironment" {
    BeforeEach {
        Mock Write-Host {}

        function Get-CodebaseLayers {}
        Mock Get-CodebaseLayers {
            return @(
                @{ Name = 'de';    Path = 'C:/fake/de'    }
                @{ Name = 'prefs'; Path = 'C:/fake/prefs' }
                @{ Name = 'prat';  Path = 'C:/fake/prat'  }
            )
        }

        function git($command) {}
        Mock git {
            if ($command -eq 'rev-parse') { return 'main' }
        }

        function Invoke-DeployCodebase($location) {}
        Mock Invoke-DeployCodebase {}

        Mock Set-Location {}
    }

    Context "de machine (3 layers)" {
        It "pulls 3 times and deploys once from de" {
            Update-DevEnvironment

            Should -Invoke -Command git -Exactly 3 -ParameterFilter { $command -eq 'pull' }
            Should -Invoke -Command Invoke-DeployCodebase -Exactly 1 -ParameterFilter { $location -eq 'C:/fake/de' }
        }
    }

    Context "prefs-only machine (2 layers)" {
        BeforeEach {
            Mock Get-CodebaseLayers {
                return @(
                    @{ Name = 'prefs'; Path = 'C:/fake/prefs' }
                    @{ Name = 'prat';  Path = 'C:/fake/prat'  }
                )
            }
        }
        It "pulls 2 times and deploys once from prefs" {
            Update-DevEnvironment

            Should -Invoke -Command git -Exactly 2 -ParameterFilter { $command -eq 'pull' }
            Should -Invoke -Command Invoke-DeployCodebase -Exactly 1 -ParameterFilter { $location -eq 'C:/fake/prefs' }
        }
    }

    Context "prat-only machine (1 layer)" {
        BeforeEach {
            Mock Get-CodebaseLayers {
                return @(
                    @{ Name = 'prat'; Path = 'C:/fake/prat' }
                )
            }
        }
        It "pulls once and deploys from prat" {
            Update-DevEnvironment

            Should -Invoke -Command git -Exactly 1 -ParameterFilter { $command -eq 'pull' }
            Should -Invoke -Command Invoke-DeployCodebase -Exactly 1 -ParameterFilter { $location -eq 'C:/fake/prat' }
        }
    }

    Context "any layer not on main" {
        It "throws without pulling any layer (single layer)" {
            Mock Get-CodebaseLayers { return @(@{ Name = 'de'; Path = 'C:/fake/de' }) }
            Mock git { if ($command -eq 'rev-parse') { return 'feature-branch' } }

            { Update-DevEnvironment } | Should -Throw "*not on main*"

            Should -Invoke -Command git -Exactly 0 -ParameterFilter { $command -eq 'pull' }
            Should -Invoke -Command Invoke-DeployCodebase -Exactly 0
        }
        It "throws without pulling any layer when second layer is not on main" {
            Mock Get-CodebaseLayers {
                return @(
                    @{ Name = 'de';    Path = 'C:/fake/de'    }
                    @{ Name = 'prefs'; Path = 'C:/fake/prefs' }
                )
            }
            $script:revParseCount = 0
            Mock git {
                if ($command -eq 'rev-parse') {
                    $script:revParseCount++
                    if ($script:revParseCount -eq 2) { return 'feature-branch' }
                    return 'main'
                }
            }

            { Update-DevEnvironment } | Should -Throw "*not on main*"

            Should -Invoke -Command git -Exactly 0 -ParameterFilter { $command -eq 'pull' }
            Should -Invoke -Command Invoke-DeployCodebase -Exactly 0
        }
    }
}

Describe "Update-DevEnvironment - location restoration" {
    BeforeEach {
        Mock Write-Host {}

        $startDir = (New-Item -ItemType Directory "TestDrive:\startdir").FullName
        $layer1 = (New-Item -ItemType Directory "TestDrive:\layer1").FullName
        $layer2 = (New-Item -ItemType Directory "TestDrive:\layer2").FullName
        Set-Location $startDir

        function Get-CodebaseLayers {}
        Mock Get-CodebaseLayers {
            return @(
                @{ Name = 'de';   Path = $layer1 }
                @{ Name = 'prat'; Path = $layer2 }
            )
        }

        function git($command) {}
        Mock git { if ($command -eq 'rev-parse') { return 'main' } }

        function Invoke-DeployCodebase($location) {}
        Mock Invoke-DeployCodebase {}
    }

    It "pwd is unchanged on success" {
        $before = $PWD.Path

        Update-DevEnvironment

        $PWD.Path | Should -Be $before
    }

    It "pwd is unchanged when a layer is not on main" {
        Mock git { if ($command -eq 'rev-parse') { return 'feature-branch' } }
        $before = $PWD.Path

        { Update-DevEnvironment } | Should -Throw

        $PWD.Path | Should -Be $before
    }
}
