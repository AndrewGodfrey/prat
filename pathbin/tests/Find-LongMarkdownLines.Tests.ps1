BeforeAll {
    . $PSScriptRoot/../Find-LongMarkdownLines.ps1

    $script:nl = [Environment]::NewLine
}

Describe "Find-LongLinesInContent" {
    Context "plain lines" {
        It "returns no findings when all lines are within the limit" {
            $result = @(Find-LongLinesInContent -Content "short line" -RelPath "foo.md" -MaxLength 120)

            $result | Should -HaveCount 0
        }

        It "flags a line over the limit" {
            $long = 'a' * 121
            $result = @(Find-LongLinesInContent -Content $long -RelPath "foo.md" -MaxLength 120)

            $result | Should -HaveCount 1
        }

        It "does not flag a line exactly at the limit (boundary)" {
            $atLimit = 'a' * 120
            $result = @(Find-LongLinesInContent -Content $atLimit -RelPath "foo.md" -MaxLength 120)

            $result | Should -HaveCount 0
        }

        It "reports the correct line number, length, path and text" {
            $long = 'a' * 121
            $content = "short" + $script:nl + $long
            $result = @(Find-LongLinesInContent -Content $content -RelPath "dir/foo.md" -MaxLength 120)

            $result | Should -HaveCount 1
            $result[0].Line   | Should -Be 2
            $result[0].Length | Should -Be 121
            $result[0].Path   | Should -Be "dir/foo.md"
            $result[0].Text   | Should -Be $long
        }

        It "honors a custom MaxLength" {
            $result = @(Find-LongLinesInContent -Content ('a' * 15) -RelPath "foo.md" -MaxLength 10)

            $result | Should -HaveCount 1
            $result[0].Length | Should -Be 15
        }
    }

    Context "fenced code blocks" {
        It "does not flag a long line inside a backtick fence" {
            $long = 'a' * 130
            $content = '```' + $script:nl + $long + $script:nl + '```'
            $result = @(Find-LongLinesInContent -Content $content -RelPath "foo.md" -MaxLength 120)

            $result | Should -HaveCount 0
        }

        It "does not flag a long line inside a tilde fence" {
            $long = 'a' * 130
            $content = '~~~' + $script:nl + $long + $script:nl + '~~~'
            $result = @(Find-LongLinesInContent -Content $content -RelPath "foo.md" -MaxLength 120)

            $result | Should -HaveCount 0
        }

        It "does not flag a fence opener carrying an info string" {
            $long = 'a' * 130
            $content = '```sql' + $script:nl + $long + $script:nl + '```'
            $result = @(Find-LongLinesInContent -Content $content -RelPath "foo.md" -MaxLength 120)

            $result | Should -HaveCount 0
        }

        It "resumes flagging after a code fence closes" {
            $long = 'a' * 130
            $content = '```' + $script:nl + $long + $script:nl + '```' + $script:nl + $long
            $result = @(Find-LongLinesInContent -Content $content -RelPath "foo.md" -MaxLength 120)

            $result | Should -HaveCount 1
            $result[0].Line | Should -Be 4
        }
    }

    Context "table rows" {
        It "does not flag a long table row" {
            $row = '| ' + ('a' * 130) + ' |'
            $result = @(Find-LongLinesInContent -Content $row -RelPath "foo.md" -MaxLength 120)

            $result | Should -HaveCount 0
        }

        It "does not flag an indented table row" {
            $row = '   | ' + ('a' * 130) + ' |'
            $result = @(Find-LongLinesInContent -Content $row -RelPath "foo.md" -MaxLength 120)

            $result | Should -HaveCount 0
        }
    }
}

Describe "Get-LongMarkdownLineFindings" {
    BeforeAll {
        $script:realTestDrive = ((Get-Item "TestDrive:\").FullName -replace '\\', '/').TrimEnd('/')
    }

    Context "directory scanning" {
        BeforeEach {
            $script:testDir = "$script:realTestDrive/flml-$([System.IO.Path]::GetRandomFileName())"
            New-Item -ItemType Directory -Path $script:testDir | Out-Null
        }
        AfterEach {
            Remove-Item $script:testDir -Recurse -Force
        }

        It "finds a long line in a .md file" {
            ('a' * 130) | Set-Content "$script:testDir/notes.md" -Encoding utf8NoBOM

            $result = @(Get-LongMarkdownLineFindings -Path $script:testDir -MaxLength 120)

            $result | Should -HaveCount 1
        }

        It "ignores non-.md files" {
            ('a' * 130) | Set-Content "$script:testDir/script.ps1" -Encoding utf8NoBOM

            $result = @(Get-LongMarkdownLineFindings -Path $script:testDir -MaxLength 120)

            $result | Should -HaveCount 0
        }

        It "returns empty for a clean directory" {
            "short line" | Set-Content "$script:testDir/clean.md" -Encoding utf8NoBOM

            $result = @(Get-LongMarkdownLineFindings -Path $script:testDir -MaxLength 120)

            $result | Should -HaveCount 0
        }
    }

    Context "single file" {
        It "scans a single .md file path" {
            $f = "$script:realTestDrive/single-$([System.IO.Path]::GetRandomFileName()).md"
            ('a' * 130) | Set-Content $f -Encoding utf8NoBOM
            try {
                $result = @(Get-LongMarkdownLineFindings -Path $f -MaxLength 120)
                $result | Should -HaveCount 1
            } finally {
                Remove-Item $f -Force
            }
        }
    }
}
