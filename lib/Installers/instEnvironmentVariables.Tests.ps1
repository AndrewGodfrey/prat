BeforeAll {
    Import-Module "$PSScriptRoot/Installers.psd1" -Force

    # Mock for InstallationStage
    class MockStage {
        [int] $changeCount = 0
        [void] OnChange() { $this.changeCount++ }
    }
}

Describe "Install-UserPathEntry" {
    BeforeEach {
        $script:stage = [MockStage]::new()
        $script:savedProcessPath = $env:PATH
        $script:mockUserPath = $null

        Mock -ModuleName Installers getUserEnvironmentVariable { $script:mockUserPath }
        Mock -ModuleName Installers setUserEnvironmentVariable { param($Name, $Value) $script:mockUserPath = $Value }
    }
    AfterEach {
        $env:PATH = $script:savedProcessPath
    }

    Context "append (default)" {
        It "adds the path to the end of User PATH and the current process PATH when absent" {
            $script:mockUserPath = "C:\a;C:\b"
            $env:PATH = "C:\a;C:\b"

            Install-UserPathEntry $stage "C:\new"

            $script:mockUserPath | Should -Be "C:\a;C:\b;C:\new"
            $env:PATH | Should -Be "C:\a;C:\b;C:\new"
            $stage.changeCount | Should -Be 2
        }

        It "is idempotent when already present" {
            $script:mockUserPath = "C:\a;C:\new"
            $env:PATH = "C:\a;C:\new"

            Install-UserPathEntry $stage "C:\new"

            $script:mockUserPath | Should -Be "C:\a;C:\new"
            $env:PATH | Should -Be "C:\a;C:\new"
            $stage.changeCount | Should -Be 0
        }
    }

    Context "-Prepend" {
        It "puts the path first in both User PATH and the current process PATH" {
            $script:mockUserPath = "C:\WindowsApps;C:\other"
            $env:PATH = "C:\WindowsApps;C:\other"

            Install-UserPathEntry $stage "C:\real\python" -Prepend

            $script:mockUserPath | Should -Be "C:\real\python;C:\WindowsApps;C:\other"
            $env:PATH | Should -Be "C:\real\python;C:\WindowsApps;C:\other"
            $stage.changeCount | Should -Be 2
        }

        It "moves an existing later occurrence to the front rather than duplicating" {
            $script:mockUserPath = "C:\WindowsApps;C:\real\python"
            $env:PATH = "C:\WindowsApps;C:\real\python"

            Install-UserPathEntry $stage "C:\real\python" -Prepend

            $script:mockUserPath | Should -Be "C:\real\python;C:\WindowsApps"
            $env:PATH | Should -Be "C:\real\python;C:\WindowsApps"
            $stage.changeCount | Should -Be 2
        }

        It "is idempotent when already first" {
            $script:mockUserPath = "C:\real\python;C:\WindowsApps"
            $env:PATH = "C:\real\python;C:\WindowsApps"

            Install-UserPathEntry $stage "C:\real\python" -Prepend

            $stage.changeCount | Should -Be 0
        }

        It "matches case-insensitively when deduping" {
            $script:mockUserPath = "C:\WindowsApps;C:\Real\Python"
            $env:PATH = "C:\WindowsApps;C:\Real\Python"

            Install-UserPathEntry $stage "c:\real\python" -Prepend

            $script:mockUserPath | Should -Be "c:\real\python;C:\WindowsApps"
            $env:PATH | Should -Be "c:\real\python;C:\WindowsApps"
        }
    }

    Context "-CurrentProcessOnly" {
        It "updates only the current process PATH, not the persistent User PATH" {
            $script:mockUserPath = "C:\a"
            $env:PATH = "C:\a"

            Install-UserPathEntry $stage "C:\new" -CurrentProcessOnly

            $script:mockUserPath | Should -Be "C:\a"
            $env:PATH | Should -Be "C:\a;C:\new"
            Should -Invoke -ModuleName Installers setUserEnvironmentVariable -Times 0
        }
    }
}

Describe "Install-UserEnvironmentVariable" {
    BeforeEach {
        $script:stage = [MockStage]::new()
        $script:mockUserPath = $null

        Mock -ModuleName Installers getUserEnvironmentVariable { $script:mockUserPath }
        Mock -ModuleName Installers setUserEnvironmentVariable { param($Name, $Value) $script:mockUserPath = $Value }
    }

    It "sets the value when it differs from the current one" {
        $script:mockUserPath = "old"

        Install-UserEnvironmentVariable $stage "SOME_VAR" "new"

        $script:mockUserPath | Should -Be "new"
        $stage.changeCount | Should -Be 1
    }

    It "is idempotent when the value already matches" {
        $script:mockUserPath = "same"

        Install-UserEnvironmentVariable $stage "SOME_VAR" "same"

        $stage.changeCount | Should -Be 0
    }
}
