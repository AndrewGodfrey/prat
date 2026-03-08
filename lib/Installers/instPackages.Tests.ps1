BeforeDiscovery {
    Import-Module "$PSScriptRoot/Installers.psd1" -Force
}

Describe "Install-PratPackage" {
    BeforeAll {
        Import-Module "$PSScriptRoot/Installers.psd1" -Force
        Mock -ModuleName Installers Write-Progress {}
        Mock -ModuleName Installers Write-Host {}
    }

    BeforeEach {
        InModuleScope Installers {
            $script:testInstallCount = 0
            $script:testInstallOrder = [System.Collections.Generic.List[string]]::new()
            $script:pratPackages = @{
                "testpkg" = @{
                    installerVersion = "2.0"
                    install = { $script:testInstallCount++ }
                }
                "dep" = @{
                    installerVersion = "1.0"
                    install = { $script:testInstallOrder.Add("dep") }
                }
                "withDep" = @{
                    installerVersion = "1.0"
                    dependencies = @("dep")
                    install = { $script:testInstallOrder.Add("withDep") }
                }
            }
        }
    }

    Context "first call" {
        It "runs install block" {
            $tracker = Start-Installation ([guid]::NewGuid().ToString()) -InstallationDatabaseLocation "TestDrive:\db-first"
            try { Install-PratPackage $tracker "testpkg" }
            finally { $tracker.StopInstallation() }

            InModuleScope Installers { $script:testInstallCount } | Should -Be 1
        }
    }

    Context "idempotency" {
        It "skips install on second call with same installerVersion" {
            $name = [guid]::NewGuid().ToString()

            $tracker = Start-Installation $name -InstallationDatabaseLocation "TestDrive:\db-idem1"
            try { Install-PratPackage $tracker "testpkg" }
            finally { $tracker.StopInstallation() }

            $tracker = Start-Installation $name -InstallationDatabaseLocation "TestDrive:\db-idem1"
            try { Install-PratPackage $tracker "testpkg" }
            finally { $tracker.StopInstallation() }

            InModuleScope Installers { $script:testInstallCount } | Should -Be 1
        }

        It "defaults to installerVersion 1.0 when installerVersion field is absent" {
            InModuleScope Installers {
                $script:pratPackages["noinstallerVersionpkg"] = @{
                    install = { $script:testInstallCount++ }
                }
            }
            $name = [guid]::NewGuid().ToString()

            $tracker = Start-Installation $name -InstallationDatabaseLocation "TestDrive:\db-idem2"
            try { Install-PratPackage $tracker "noinstallerVersionpkg" }
            finally { $tracker.StopInstallation() }

            $tracker = Start-Installation $name -InstallationDatabaseLocation "TestDrive:\db-idem2"
            try { Install-PratPackage $tracker "noinstallerVersionpkg" }
            finally { $tracker.StopInstallation() }

            InModuleScope Installers { $script:testInstallCount } | Should -Be 1
        }
    }

    Context "installerVersion bumping" {
        It "re-runs install when installerVersion is bumped" {
            $name = [guid]::NewGuid().ToString()

            $tracker = Start-Installation $name -InstallationDatabaseLocation "TestDrive:\db-bump"
            try { Install-PratPackage $tracker "testpkg" }
            finally { $tracker.StopInstallation() }

            InModuleScope Installers { $script:pratPackages["testpkg"].installerVersion = "3.0" }

            $tracker = Start-Installation $name -InstallationDatabaseLocation "TestDrive:\db-bump"
            try { Install-PratPackage $tracker "testpkg" }
            finally { $tracker.StopInstallation() }

            InModuleScope Installers { $script:testInstallCount } | Should -Be 2
        }
    }

    Context "dependencies" {
        It "installs dependency before dependent package" {
            $tracker = Start-Installation ([guid]::NewGuid().ToString()) -InstallationDatabaseLocation "TestDrive:\db-deps"
            try { Install-PratPackage $tracker "withDep" }
            finally { $tracker.StopInstallation() }

            InModuleScope Installers { $script:testInstallOrder.ToArray() } | Should -Be @("dep", "withDep")
        }
    }
}
