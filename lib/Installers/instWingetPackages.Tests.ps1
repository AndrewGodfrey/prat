BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')

    class MockStage {
        [int] $changeCount = 0
        [void] OnChange() { $this.changeCount++ }
        [void] SetSubstage([string] $name) {}
    }
}

Describe "Install-WingetPackage" {
    BeforeEach {
        $script:stage = [MockStage]::new()
        Mock installWingetPackage {}
        Mock isWingetPackageInstalled { return $true }
        Mock isWingetPackageInstalledMachineScope { return $false }
    }

    Context "installPath present" {
        It "skips install when installPath exists" {
            $path = "TestDrive:\existing"
            New-Item $path -ItemType Directory | Out-Null

            Install-WingetPackage $stage "Foo.Bar" $path

            $stage.changeCount | Should -Be 0
            Should -Not -Invoke installWingetPackage
        }
    }

    Context "installPath absent" {
        It "installs and calls OnChange" {
            $script:newPath = "TestDrive:\new-install"
            Mock installWingetPackage { New-Item $script:newPath -ItemType Directory | Out-Null }

            Install-WingetPackage $stage "Foo.Bar" $script:newPath

            $stage.changeCount | Should -Be 1
            Should -Invoke installWingetPackage -Times 1 -ParameterFilter { $packageId -eq "Foo.Bar" }
        }

        It "throws if installPath not created after install" {
            $path = "TestDrive:\broken-install"

            { Install-WingetPackage $stage "Foo.Bar" $path } | Should -Throw
        }
    }

    Context "machine-scope already installed" {
        It "skips install when machine-scope package is present" {
            $path = "TestDrive:\not-present"
            Mock isWingetPackageInstalledMachineScope { return $true }

            Install-WingetPackage $stage "Foo.Bar" $path

            $stage.changeCount | Should -Be 0
            Should -Not -Invoke installWingetPackage
        }
    }

    Context "-AlternatePaths" {
        It "skips install when alternate path exists" {
            $primaryPath = "TestDrive:\user-vscode"    # does not exist
            $altPath = "TestDrive:\system-vscode"
            New-Item $altPath -ItemType Directory | Out-Null

            Install-WingetPackage $stage "Foo.Bar" $primaryPath -AlternatePaths @($altPath)

            $stage.changeCount | Should -Be 0
            Should -Not -Invoke installWingetPackage
        }

        It "installs when neither primary nor alternate path exists" {
            $script:p2 = "TestDrive:\user-vscode2"
            $altPath = "TestDrive:\system-vscode2"    # does not exist
            Mock installWingetPackage { New-Item $script:p2 -ItemType Directory | Out-Null }

            Install-WingetPackage $stage "Foo.Bar" $script:p2 -AlternatePaths @($altPath)

            $stage.changeCount | Should -Be 1
            Should -Invoke installWingetPackage -Times 1
        }

        It "skips install when one of multiple alternate paths exists" {
            $primaryPath = "TestDrive:\user-vscode3"
            $alt1 = "TestDrive:\alt1"                 # does not exist
            $alt2 = "TestDrive:\alt2"
            New-Item $alt2 -ItemType Directory | Out-Null

            Install-WingetPackage $stage "Foo.Bar" $primaryPath -AlternatePaths @($alt1, $alt2)

            $stage.changeCount | Should -Be 0
            Should -Not -Invoke installWingetPackage
        }
    }
}
