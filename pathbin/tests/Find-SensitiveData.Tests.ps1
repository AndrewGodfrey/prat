BeforeAll {
    . $PSScriptRoot/../Find-SensitiveData.ps1
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
            $result = @(Find-SensitiveDataInContent -Content "contact user@example.com here" -RelPath "foo.ps1" -HomeDir "C:\Users\alice")

            $result | Should -HaveCount 1
            $result[0] | Should -Match "email address"
        }

        It "flags an email in a comment" {
            $result = @(Find-SensitiveDataInContent -Content "# send to andrew@home.net" -RelPath "foo.ps1" -HomeDir "C:\Users\alice")

            $result | Should -HaveCount 1
            $result[0] | Should -Match "email address"
        }

        It "reports the file path in the finding" {
            $result = @(Find-SensitiveDataInContent -Content "user@example.com" -RelPath "lib/foo.ps1" -HomeDir "C:\Users\alice")

            $result[0] | Should -Match "lib/foo\.ps1"
        }
    }

    Context "IP addresses" {
        It "flags a dotted-quad IP address" {
            $result = @(Find-SensitiveDataInContent -Content "server at 192.168.1.10" -RelPath "foo.ps1" -HomeDir "C:\Users\alice")

            $result | Should -HaveCount 1
            $result[0] | Should -Match "IP address"
        }
    }

    Context "multiple findings" {
        It "returns one finding per pattern matched, not per occurrence" {
            $content = "user@a.com user@b.com"
            $result = @(Find-SensitiveDataInContent -Content $content -RelPath "foo.ps1" -HomeDir "C:\Users\alice")

            $result | Should -HaveCount 1
            $result[0] | Should -Match "email address"
        }

        It "returns one finding per pattern type when multiple types match" {
            $content = "C:\Users\alice\prat and user@example.com and 10.0.0.1"
            $result = @(Find-SensitiveDataInContent -Content $content -RelPath "foo.ps1" -HomeDir "C:\Users\alice")

            $result | Should -HaveCount 3
        }
    }
}
