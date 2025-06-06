using module .\PratBase.psd1

Describe "Get-RelativePath" {
    It "returns a relative path" {
        $p = Get-RelativePath $PSScriptRoot "$PSScriptRoot\PratBase.psd1"
        $p | Should -Be "PratBase.psd1"
    }
    It "returns a relative path to a subdirectory" {
        $p = Get-RelativePath $PSScriptRoot "$PSScriptRoot\test\"
        $p | Should -Be "test\"
    }
    It "returns a relative path to file in a subdirectory" {
        $p = Get-RelativePath $PSScriptRoot "$PSScriptRoot\test\dummytestfile.txt"
        $p | Should -Be "test\dummytestfile.txt"
    }
    It "uses upper/lowercase from the filesystem, not the parameter" {
        $p = Get-RelativePath "$PSScriptRoot\TeSt" "$PSScriptRoot\test\dummyTestfile.txt"
        $p | Should -Be "dummytestfile.txt"
    }
    It "returns an empty string (not '.') if given the root" {
        $p = Get-RelativePath $PSScriptRoot $PSScriptRoot
        $p | Should -Be ""
    }
}

Describe "Get-OptimalSize" {
    It "returns various sizes" {
        function kpow($n) {
            [int64] $result = 1
            while ($n -gt 0) {
                $result *= 1000
                $n--
            }
            return $result
        }
        Get-OptimalSize 1 | Should -Be "1"
        Get-OptimalSize 999 | Should -Be "999"
        Get-OptimalSize 1000 | Should -Be "1.0K"
        Get-OptimalSize (kpow 2) | Should -Be "1.0MB"
        Get-OptimalSize (kpow 3) | Should -Be "1.0GB"
        Get-OptimalSize (kpow 4) | Should -Be "1.0TB"
        Get-OptimalSize (kpow 5) | Should -Be "1.0PB"
    }
}

Describe "Test-PathIsUnder" {
    It "returns true for a path under the root" {
        Test-PathIsUnder "\testRoot\foo" "\testRoot" | Should -Be $true
    }
    It "returns false for a path not under the root" {
        Test-PathIsUnder "\foo" "\testRoot" | Should -Be $false
    }
    It "returns true for a path that is the root" {
        Test-PathIsUnder "\testRoot" "\testRoot" | Should -Be $true
    }
}

Describe "Restart-Process" {
    BeforeAll {
        Mock -ModuleName PratBase Get-CurrentUserIsElevated { $false }
        Mock -ModuleName PratBase Stop-Process {} -Verifiable
        Mock -ModuleName PratBase Start-Sleep {}
        Mock -ModuleName PratBase Invoke-Item {} -Verifiable
    }
    It "restarts a process" {
        Mock -ModuleName PratBase Get-CimInstance{
            return @(
                @{
                Name = "test.exe"
                ProcessId = 1234
                CommandLine = '"C:\test\test.exe" '
                ExecutablePath = "C:\test\test.exe"
                }
            )
        }

        Restart-Process "test.exe"

        Should -Invoke -ModuleName PratBase Stop-Process -Times 1
        Should -Invoke -ModuleName PratBase Stop-Process -Times 1 -ParameterFilter { $_.Id -eq $processId }        
        Should -Invoke -ModuleName PratBase Invoke-Item -Times 1 -ParameterFilter { $_.Path -eq $executablePath }
    }

    It "throws if it doesn't understand the command-line arguments" {
        Mock -ModuleName PratBase Get-CimInstance {
            return @(
                @{
                Name = "test.exe"
                ProcessId = 1234
                CommandLine = 'foo bar'
                ExecutablePath = "C:\test\test.exe"
                }
            )
        }

        {Restart-Process "test.exe"} | Should -Throw "Unsupported: There seem to be command line arguments: foo bar"
    }
}

Describe "New-FolderAndParents" {
    BeforeAll {
        $root = "TestDrive:\New-FolderAndParents"
        New-Item -Path $root -ItemType Directory -Force | Out-Null
    }
    It "creates a folder and its parents" {
        $newPath = "$root\test\subfolder"
        Test-Path $newPath | Should -Be $false

        New-FolderAndParents $newPath

        Test-Path $newPath | Should -Be $true
    }
    It "does not create an existing folder" {
        Mock New-Subfolder { } -Verifiable

        New-FolderAndParents $root

        Should -Invoke New-Subfolder -Times 0
    }
}

Describe "New-Subfolder" {
    Context "User not elevated" {
        BeforeAll {
            Mock Get-CurrentUserIsElevated { $false }
            $root = "TestDrive:\New-Subfolder"
            New-Item -Path $root -ItemType Directory -Force | Out-Null
        }
        It "creates a subfolder" {
            $newPath = "$root\test"
            Test-Path $newPath | Should -Be $false
            New-Subfolder $newPath
            Test-Path $newPath | Should -Be $true
        }
        It "fails if the parent folder does not exist" {
            Test-Path "$root\test2" | Should -Be $false
            $newPath = "$root\test2\foo"

            {New-Subfolder $newPath} | Should -Throw "Not found: $root\test2"
        }
    }
}
