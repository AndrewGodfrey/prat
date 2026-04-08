BeforeDiscovery {
    Import-Module "$PSScriptRoot/../PratBase/PratBase.psd1" -Force
    Import-Module "$PSScriptRoot/Installers.psd1" -Force
}

Describe "Install-PratPackage" {
    BeforeAll {
        Import-Module "$PSScriptRoot/../PratBase/PratBase.psd1" -Force
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

    Context "getLatestVersion" {
        BeforeEach {
            InModuleScope Installers {
                $script:capturedTargetVersion = $null
                $script:pratPackages["versionpkg"] = @{
                    getLatestVersion = { "1.2.3" }
                    check            = { param($stage, $targetVersion) $script:capturedTargetVersion = $targetVersion; $false }
                    install          = { param($stage, $targetVersion) $script:testInstallCount++ }
                }
            }
        }

        It "threads resolved version to check" {
            $tracker = Start-Installation ([guid]::NewGuid().ToString()) -InstallationDatabaseLocation "TestDrive:\db-ver1"
            try { Install-PratPackage $tracker "versionpkg" }
            finally { $tracker.StopInstallation() }

            InModuleScope Installers { $script:capturedTargetVersion } | Should -Be "1.2.3"
        }

        It "threads resolved version to install" {
            InModuleScope Installers {
                $script:pratPackages["versionpkg"].install = { param($stage, $targetVersion) $script:capturedTargetVersion = $targetVersion }
                $script:pratPackages["versionpkg"].check   = { param($stage, $targetVersion) $false }
            }

            $tracker = Start-Installation ([guid]::NewGuid().ToString()) -InstallationDatabaseLocation "TestDrive:\db-ver2"
            try { Install-PratPackage $tracker "versionpkg" }
            finally { $tracker.StopInstallation() }

            InModuleScope Installers { $script:capturedTargetVersion } | Should -Be "1.2.3"
        }
    }

    Context "check scriptblock" {
        BeforeEach {
            InModuleScope Installers {
                $script:checkResult = $false
                $script:pratPackages["checkpkg"] = @{
                    check   = { $script:checkResult }
                    install = { $script:testInstallCount++ }
                }
            }
        }

        It "skips install when check returns true" {
            InModuleScope Installers { $script:checkResult = $true }
            $tracker = Start-Installation ([guid]::NewGuid().ToString()) -InstallationDatabaseLocation "TestDrive:\db-check-skip"
            try { Install-PratPackage $tracker "checkpkg" }
            finally { $tracker.StopInstallation() }

            InModuleScope Installers { $script:testInstallCount } | Should -Be 0
        }

        It "runs install when check returns false" {
            $tracker = Start-Installation ([guid]::NewGuid().ToString()) -InstallationDatabaseLocation "TestDrive:\db-check-run"
            try { Install-PratPackage $tracker "checkpkg" }
            finally { $tracker.StopInstallation() }

            InModuleScope Installers { $script:testInstallCount } | Should -Be 1
        }

        It "re-runs install on repeated calls while check returns false" {
            $name = [guid]::NewGuid().ToString()

            $tracker = Start-Installation $name -InstallationDatabaseLocation "TestDrive:\db-check-repeat"
            try { Install-PratPackage $tracker "checkpkg" }
            finally { $tracker.StopInstallation() }

            $tracker = Start-Installation $name -InstallationDatabaseLocation "TestDrive:\db-check-repeat"
            try { Install-PratPackage $tracker "checkpkg" }
            finally { $tracker.StopInstallation() }

            InModuleScope Installers { $script:testInstallCount } | Should -Be 2
        }
    }
}

Describe "Get-DotnetSdkRequirement" {
    BeforeAll {
        Import-Module "$PSScriptRoot/Installers.psd1" -Force
    }

    It "latestFeature: Pattern is major.minor.*, Major is major version" {
        Set-Content "TestDrive:\gj-lf.json" '{"sdk":{"version":"8.0.100","rollForward":"latestFeature"}}'
        $result = InModuleScope Installers { Get-DotnetSdkRequirement "TestDrive:\gj-lf.json" }
        $result.Major   | Should -Be '8'
        $result.Pattern | Should -Be '8.0.*'
    }

    It "latestMinor: Pattern is major.*" {
        Set-Content "TestDrive:\gj-lm.json" '{"sdk":{"version":"9.1.200","rollForward":"latestMinor"}}'
        $result = InModuleScope Installers { Get-DotnetSdkRequirement "TestDrive:\gj-lm.json" }
        $result.Major   | Should -Be '9'
        $result.Pattern | Should -Be '9.*'
    }

    It "latestMajor: Pattern is *" {
        Set-Content "TestDrive:\gj-lmaj.json" '{"sdk":{"version":"8.0.100","rollForward":"latestMajor"}}'
        $result = InModuleScope Installers { Get-DotnetSdkRequirement "TestDrive:\gj-lmaj.json" }
        $result.Major   | Should -Be '8'
        $result.Pattern | Should -Be '*'
    }

    It "throws on unsupported rollForward value" {
        Set-Content "TestDrive:\gj-bad.json" '{"sdk":{"version":"8.0.100","rollForward":"disable"}}'
        { InModuleScope Installers { Get-DotnetSdkRequirement "TestDrive:\gj-bad.json" } } | Should -Throw "*disable*"
    }
}

Describe "installPratWingetPackage" {
    BeforeAll {
        Import-Module "$PSScriptRoot/Installers.psd1" -Force
        Mock -ModuleName Installers invokeWingetUserScope { $global:LASTEXITCODE = 0 }
    }

    It "skips user-scope install when package is already installed at machine scope" {
        Mock -ModuleName Installers isWingetPackageInstalledMachineScope { return $true }

        InModuleScope Installers { installPratWingetPackage "Some.Package" }

        Should -Not -Invoke invokeWingetUserScope -ModuleName Installers
    }

    It "runs user-scope install when package is not installed at machine scope" {
        Mock -ModuleName Installers isWingetPackageInstalledMachineScope { return $false }

        InModuleScope Installers { installPratWingetPackage "Some.Package" }

        Should -Invoke invokeWingetUserScope -ModuleName Installers -Times 1
    }
}

Describe "getClaudeInstaller" {
    BeforeAll {
        Import-Module "$PSScriptRoot/Installers.psd1" -Force
    }

    Context "getLatestVersion" {
        It "returns latest version from GCS" {
            Mock -ModuleName Installers Invoke-RestMethod { return "1.3.0`n" }

            $result = InModuleScope Installers { &((getClaudeInstaller).getLatestVersion) }

            $result | Should -Be "1.3.0"
        }

        It "returns null on network failure" {
            Mock -ModuleName Installers Invoke-RestMethod { throw "network error" }

            $result = InModuleScope Installers { &((getClaudeInstaller).getLatestVersion) }

            $result | Should -BeNullOrEmpty
        }
    }
}

Describe "installClaude" {
    BeforeAll {
        Import-Module "$PSScriptRoot/Installers.psd1" -Force
        Mock -ModuleName Installers invokeClaudeInstaller {}
        Mock -ModuleName Installers Install-UserPathEntry {}
        Mock -ModuleName Installers Write-Host {}
        Mock -ModuleName Installers getInstalledClaudeVersion { return $null }
    }

    It "warns and skips when Claude is running and user presses Enter" {
        Mock -ModuleName Installers isClaudeRunning { return $true }
        Mock -ModuleName Installers Read-Host { return '' }

        $warnings = InModuleScope Installers { installClaude $null $null } 3>&1 |
            Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

        $warnings | Should -Not -BeNullOrEmpty
        Should -Not -Invoke invokeClaudeInstaller -ModuleName Installers
    }

    It "installs when Claude is running and user types 'd'" {
        Mock -ModuleName Installers isClaudeRunning { return $true }
        Mock -ModuleName Installers Read-Host { return 'd' }
        Mock -ModuleName Installers Test-Path { return $true } -ParameterFilter { $Path -like "*claude.exe" }

        InModuleScope Installers { installClaude $null $null }

        Should -Invoke invokeClaudeInstaller -ModuleName Installers -Times 1
    }

    It "includes version info in warning when available" {
        Mock -ModuleName Installers isClaudeRunning { return $true }
        Mock -ModuleName Installers Read-Host { return '' }
        Mock -ModuleName Installers getInstalledClaudeVersion { return "1.2.3" }

        $warnings = InModuleScope Installers { installClaude $null "1.3.0" } 3>&1 |
            Where-Object { $_ -is [System.Management.Automation.WarningRecord] }

        $warnings.Message | Should -Match "1\.2\.3"
        $warnings.Message | Should -Match "1\.3\.0"
    }

    It "passes targetVersion to invokeClaudeInstaller" {
        Mock -ModuleName Installers isClaudeRunning { return $false }
        Mock -ModuleName Installers Test-Path { return $true } -ParameterFilter { $Path -like "*claude.exe" }

        InModuleScope Installers { installClaude $null "1.3.0" }

        Should -Invoke invokeClaudeInstaller -ModuleName Installers -Times 1 -ParameterFilter { $targetVersion -eq "1.3.0" }
    }

    It "runs installer when Claude is not running" {
        Mock -ModuleName Installers isClaudeRunning { return $false }
        Mock -ModuleName Installers Test-Path { return $true } -ParameterFilter { $Path -like "*claude.exe" }

        InModuleScope Installers { installClaude $null $null }

        Should -Invoke invokeClaudeInstaller -ModuleName Installers -Times 1
    }
}
