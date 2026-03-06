BeforeAll {
    Import-Module "$PSScriptRoot\PratBase.psd1" -Force
}

Describe "Find-ProjectShortcut" {
    BeforeEach {
        $dir = (Get-Item "TestDrive:\").FullName.TrimEnd('\').Replace('\', '/')
    }

    It "-ListAll returns shortcuts sorted alphabetically" {
        "@{ '.' = @{ repos = @{ z = @{} }; shortcuts = @{ b = 'b'; a = 'a' } } }" | Out-File "TestDrive:\repoProfile_test.ps1"
        Mock Get-RepoProfileFiles -ModuleName PratBase { return @("$dir/repoProfile_test.ps1") }

        $keys = @((Find-ProjectShortcut -ListAll).Keys)

        $keys | Should -Be ($keys | Sort-Object)
    }
}

Describe "Import-Scriptblock" {
    InModuleScope PratBase {
        BeforeEach {
            $dir = (Get-Item "TestDrive:\").FullName.TrimEnd('\').Replace('\', '/')
        }

        It "Strips module association from top-level scriptblocks" {
            "@{ sb = { 'hello' } }" | Out-File "TestDrive:\t.ps1"
            (Import-Scriptblock "$dir/t.ps1").sb.Module | Should -BeNull
        }

        It "Strips module association from scriptblocks nested in hashtables" {
            "@{ outer = @{ sb = { 'hello' } } }" | Out-File "TestDrive:\t.ps1"
            (Import-Scriptblock "$dir/t.ps1").outer.sb.Module | Should -BeNull
        }

        It "Non-scriptblock values pass through unchanged" {
            "@{ x = 42; s = 'hello' }" | Out-File "TestDrive:\t.ps1"
            $result = Import-Scriptblock "$dir/t.ps1"
            $result.x | Should -Be 42
            $result.s | Should -Be 'hello'
        }

        It "LIMITATION: Closures are not preserved - variable resolves at invocation time, not capture time" {
            # After stripping, the scriptblock source text is recompiled with no captured environment.
            # $x is looked up in the caller's scope at invocation time, not the original closure scope.
            # Workaround: use [scriptblock]::Create() in the data file to bake values into source text.
            $x = "at-definition"
            $sb = { $x }.GetNewClosure()
            $stripped = Strip-Scriptblocks $sb
            $x = "at-invocation"
            & $stripped | Should -Be "at-invocation"  # NOT "at-definition"
        }
    }
}
