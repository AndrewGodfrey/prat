BeforeAll {
    . $PSScriptRoot/../Find-SensitiveData.ps1

    $sampleEmail = "user" + "@badexample.com"
}

Describe "Find-SensitiveDataInContent" {
    Context "clean content" {
        It "returns no findings for clean content" {
            $result = @(Find-SensitiveDataInContent -Content "hello world" -RelPath "foo.ps1" -HomeDir "C:\Users\alice")

            $result | Should -HaveCount 0
        }

        It "does not flag `$home variable usage" {
            $result = @(Find-SensitiveDataInContent -Content '$home\prat\lib\foo.ps1' -RelPath "foo.ps1" -HomeDir "C:\Users\alice")

            $result | Should -HaveCount 0
        }
    }

    Context "hardcoded home path" {
        It "flags the exact home directory string" {
            $result = @(Find-SensitiveDataInContent -Content "path = C:\Users\alice\prat" -RelPath "foo.ps1" -HomeDir "C:\Users\alice")

            $result | Should -HaveCount 1
            $result[0] | Should -Match "hardcoded home path"
        }

        It "does not flag a different user's path" {
            $result = @(Find-SensitiveDataInContent -Content "C:\Users\bob\prat" -RelPath "foo.ps1" -HomeDir "C:\Users\alice")

            $result | Should -HaveCount 0
        }
    }

    Context "email addresses" {
        It "flags a plain email address" {
            $result = @(Find-SensitiveDataInContent -Content "contact $sampleEmail here" -RelPath "foo.ps1" -HomeDir "C:\Users\alice")

            $result | Should -HaveCount 1
            $result[0] | Should -Match "email address"
        }

        It "flags an email in a comment" {
            $result = @(Find-SensitiveDataInContent -Content "# send to $sampleEmail" -RelPath "foo.ps1" -HomeDir "C:\Users\alice")

            $result | Should -HaveCount 1
            $result[0] | Should -Match "email address"
        }

        It "reports the file path in the finding" {
            $result = @(Find-SensitiveDataInContent -Content $sampleEmail -RelPath "lib/foo.ps1" -HomeDir "C:\Users\alice")

            $result[0] | Should -Match "lib/foo\.ps1"
        }
    }

    Context "IP addresses" {
        It "flags a dotted-quad IP address" {
            $result = @(Find-SensitiveDataInContent -Content ("server at 192.168" + ".1.10") -RelPath "foo.ps1" -HomeDir "C:\Users\alice")

            $result | Should -HaveCount 1
            $result[0] | Should -Match "IP address"
        }
    }

    Context "de plans path" {
        BeforeAll {
            $dePlans = "de" + "/plans"
            $dePlansBackslash = "de" + "\plans"
        }
        It "flags de plans (forward slash)" {
            $result = @(Find-SensitiveDataInContent -Content "`$home/$dePlans" -RelPath "foo.ps1" -HomeDir "C:\Users\alice")

            $result | Should -HaveCount 1
            $result[0] | Should -Match $dePlans
        }

        It "flags de plans (backslash)" {
            $result = @(Find-SensitiveDataInContent -Content "`$home\$dePlansBackslash" -RelPath "foo.ps1" -HomeDir "C:\Users\alice")

            $result | Should -HaveCount 1
            $result[0] | Should -Match $dePlans
        }

        It "does not flag an unrelated path containing 'plans'" {
            $result = @(Find-SensitiveDataInContent -Content '$home/prat/auto/plans' -RelPath "foo.ps1" -HomeDir "C:\Users\alice")

            $result | Should -HaveCount 0
        }
    }

    Context "multiple findings" {
        It "returns one finding per pattern matched, not per occurrence" {
            $content = "user@" + "a.com user" + "@b.com"
            $result = @(Find-SensitiveDataInContent -Content $content -RelPath "foo.ps1" -HomeDir "C:\Users\alice")

            $result | Should -HaveCount 1
            $result[0] | Should -Match "email address"
        }

        It "returns one finding per pattern type when multiple types match" {
            $content = "C:\Users\alice\prat and $sampleEmail and 10.0" + ".0.1"
            $result = @(Find-SensitiveDataInContent -Content $content -RelPath "foo.ps1" -HomeDir "C:\Users\alice")

            $result | Should -HaveCount 3
        }
    }
}

Describe "Get-SensitiveDataFindings" {
    BeforeEach {
        $script:testDir = Join-Path (Resolve-Path "TestDrive:\").ProviderPath "fsd-test"
        mkdir $testDir | Out-Null
    }
    AfterEach {
        Remove-Item $testDir -Recurse -Force
    }

    Context "directory path" {
        It "finds sensitive data in a file in the directory" {
            "C:\Users\alice\prat" | Set-Content "$testDir\script.ps1" -Encoding utf8NoBOM

            $result = @(Get-SensitiveDataFindings -Path $testDir -HomeDir "C:\Users\alice")

            $result | Should -HaveCount 1
            $result[0] | Should -Match "hardcoded home path"
        }

        It "returns empty for a clean directory" {
            "hello world" | Set-Content "$testDir\clean.ps1" -Encoding utf8NoBOM

            $result = @(Get-SensitiveDataFindings -Path $testDir -HomeDir "C:\Users\alice")

            $result | Should -HaveCount 0
        }
    }

    Context "file path" {
        It "finds sensitive data in a single file" {
            $file = "$testDir\secret.ps1"
            "C:\Users\alice\prat" | Set-Content $file -Encoding utf8NoBOM

            $result = @(Get-SensitiveDataFindings -Path $file -HomeDir "C:\Users\alice")

            $result | Should -HaveCount 1
            $result[0] | Should -Match "hardcoded home path"
        }

        It "returns empty for a clean file" {
            $file = "$testDir\clean.ps1"
            "hello world" | Set-Content $file -Encoding utf8NoBOM

            $result = @(Get-SensitiveDataFindings -Path $file -HomeDir "C:\Users\alice")

            $result | Should -HaveCount 0
        }
    }
}
