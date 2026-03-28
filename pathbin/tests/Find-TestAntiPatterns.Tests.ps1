BeforeAll {
    . $PSScriptRoot/../Find-TestAntiPatterns.ps1
    $script:ep = '$' + 'env:'
}

Describe "Find-TestAntiPatternsInContent" {
    Context "clean content" {
        It "returns no findings for clean content" {
            $result = @(Find-TestAntiPatternsInContent 'Write-Host "hello"' "t.Tests.ps1")

            $result | Should -HaveCount 0
        }

        It "does not flag write cmdlets targeting TestDrive" {
            $result = @(Find-TestAntiPatternsInContent 'Set-Content "$TestDrive/file.txt" "hi"' "t.Tests.ps1")

            $result | Should -HaveCount 0
        }

        It "does not flag reading from `$home" {
            $result = @(Find-TestAntiPatternsInContent 'Get-Content "$home/config.json"' "t.Tests.ps1")

            $result | Should -HaveCount 0
        }
    }

    Context "env var written without save pattern" {
        It "flags an unread env var write" {
            $result = @(Find-TestAntiPatternsInContent ($script:ep + 'PATH = "C:/fake"') "t.Tests.ps1")

            $result | Should -HaveCount 1
            $result[0] | Should -Match 'env var'
            $result[0] | Should -Match 'PATH'
        }

        It "includes the line number in the finding" {
            $content = "# preamble" + [Environment]::NewLine + ($script:ep + 'MY_VAR = "x"')
            $result = @(Find-TestAntiPatternsInContent $content "t.Tests.ps1")

            $result[0] | Should -Match 'line 2'
        }

        It "shows 'and N more' when hits exceed MaxFoundLines" {
            $nl = [Environment]::NewLine
            $content = ($script:ep + 'FOO = "a"') + $nl + ($script:ep + 'FOO = "b"') + $nl + ($script:ep + 'FOO = "c"')
            $result = @(Find-TestAntiPatternsInContent $content "t.Tests.ps1" -MaxFoundLines 2)

            $result[0] | Should -Match 'line 1, 2'
            $result[0] | Should -Match 'and 1 more'
        }

        It "does not flag when save pattern exists (simple assignment)" {
            $content = '$savedPath = $env:PATH' + [Environment]::NewLine + ($script:ep + 'PATH = "C:/fake"')
            $result = @(Find-TestAntiPatternsInContent $content "t.Tests.ps1")

            $result | Should -HaveCount 0
        }

        It "does not flag self-reference on RHS" {
            $result = @(Find-TestAntiPatternsInContent ($script:ep + 'PATH = ' + $script:ep + 'PATH + ";extra"') "t.Tests.ps1")

            $result | Should -HaveCount 0
        }

        It "does not flag when hashtable save pattern exists" {
            $content = '$prev = @{ myVar = $env:myVar }' + [Environment]::NewLine + ($script:ep + 'myVar = "foo"')
            $result = @(Find-TestAntiPatternsInContent $content "t.Tests.ps1")

            $result | Should -HaveCount 0
        }

        It "flags each unsaved variable once even if written multiple times" {
            $content = ($script:ep + 'FOO = "a"') + [Environment]::NewLine + ($script:ep + 'FOO = "b"')
            $result = @(Find-TestAntiPatternsInContent $content "t.Tests.ps1")

            $result | Should -HaveCount 1
        }

        It "flags two distinct unsaved variables independently" {
            $content = ($script:ep + 'FOO = "a"') + [Environment]::NewLine + ($script:ep + 'BAR = "b"')
            $result = @(Find-TestAntiPatternsInContent $content "t.Tests.ps1")

            $result | Should -HaveCount 2
        }

        It "does not flag saved variable when a second unsaved variable is also present" {
            $content = '$savedPath = $env:PATH' + [Environment]::NewLine +
                       ($script:ep + 'PATH = "x"') + [Environment]::NewLine +
                       ($script:ep + 'MY_NEW_VAR = "y"')
            $result = @(Find-TestAntiPatternsInContent $content "t.Tests.ps1")

            $result | Should -HaveCount 1
            $result[0] | Should -Match 'MY_NEW_VAR'
            $result[0] | Should -Not -Match 'PATH'
        }

        It "includes the variable name and file path in the finding" {
            $result = @(Find-TestAntiPatternsInContent ($script:ep + 'MY_VAR = "x"') "lib/Foo.Tests.ps1")

            $result[0] | Should -Match 'MY_VAR'
            $result[0] | Should -Match 'lib/Foo\.Tests\.ps1'
        }
    }

    Context "write cmdlet targeting `$home" {
        BeforeAll {
            # Split the trigger string so the scanner doesn't flag this test file itself.
            # (Same technique as Find-SensitiveData.Tests.ps1 uses for email addresses.)
            $script:h = '$' + 'home'
        }

        It "includes the line number in the finding" {
            $content = "# preamble" + [Environment]::NewLine + ('Set-Content "' + $script:h + '/f" "y"')
            $result = @(Find-TestAntiPatternsInContent $content "t.Tests.ps1")

            $result[0] | Should -Match 'line 2'
        }

        It "flags Set-Content targeting a home path" {
            $result = @(Find-TestAntiPatternsInContent ('Set-Content "' + $script:h + '/file.txt" "content"') "t.Tests.ps1")

            $result | Should -HaveCount 1
            $result[0] | Should -Match 'home'
        }

        It "flags Out-File targeting a home path" {
            $result = @(Find-TestAntiPatternsInContent ('"content" | Out-File "' + $script:h + '/log.txt"') "t.Tests.ps1")

            $result | Should -HaveCount 1
        }

        It "flags New-Item targeting a home path" {
            $result = @(Find-TestAntiPatternsInContent ('New-Item "' + $script:h + '/testdir" -ItemType Directory') "t.Tests.ps1")

            $result | Should -HaveCount 1
        }

        It "flags Add-Content targeting a home path" {
            $result = @(Find-TestAntiPatternsInContent ('Add-Content "' + $script:h + '/log.txt" "line"') "t.Tests.ps1")

            $result | Should -HaveCount 1
        }

        It "does not flag writes to non-home paths" {
            $result = @(Find-TestAntiPatternsInContent 'Set-Content "$testRoot/file.txt" "content"' "t.Tests.ps1")

            $result | Should -HaveCount 0
        }

        It "does not flag `$homeDir (word boundary — not the same as `$home)" {
            $result = @(Find-TestAntiPatternsInContent 'Set-Content "$homeDir/file.txt" "content"' "t.Tests.ps1")

            $result | Should -HaveCount 0
        }

        It "reports one finding per file regardless of how many matching lines" {
            $content = ('Set-Content "' + $script:h + '/a.txt" "x"') + [Environment]::NewLine +
                       ('Add-Content "' + $script:h + '/b.txt" "y"')
            $result = @(Find-TestAntiPatternsInContent $content "t.Tests.ps1")

            $result | Where-Object { $_ -match 'home' } | Should -HaveCount 1
        }

        It "includes the file path in the finding" {
            $result = @(Find-TestAntiPatternsInContent ('Set-Content "' + $script:h + '/x" "y"') "lib/Foo.Tests.ps1")

            $result[0] | Should -Match 'lib/Foo\.Tests\.ps1'
        }
    }

    Context "multiple finding types" {
        BeforeAll { $script:h = '$' + 'home' }

        It "returns findings from both checks when both apply" {
            $content = '$env:PATH = "x"' + [Environment]::NewLine + ('Set-Content "' + $script:h + '/f" "y"')
            $result = @(Find-TestAntiPatternsInContent $content "t.Tests.ps1")

            $result | Should -HaveCount 2
        }
    }

    Context "push/pop environment helper pair" {
        It "does not flag env var write when well-formed push/pop pair is present" {
            $content = '$prev = pushTestEnvironment' + [Environment]::NewLine +
                       'try { $env:testenvvar = "foo" } finally { popTestEnvironment $prev }'
            $result = @(Find-TestAntiPatternsInContent $content "t.Tests.ps1")

            $result | Should -HaveCount 0
        }

        It "still flags when push is present but pop is missing" {
            $content = '$prev = pushTestEnvironment' + [Environment]::NewLine +
                       '$env:testenvvar = "foo"'
            $result = @(Find-TestAntiPatternsInContent $content "t.Tests.ps1")

            $result | Should -HaveCount 1
        }

        It "still flags when pop is present but push result is not stored" {
            $content = 'pushTestEnvironment' + [Environment]::NewLine +
                       '$env:testenvvar = "foo"' + [Environment]::NewLine +
                       'popTestEnvironment $prev'
            $result = @(Find-TestAntiPatternsInContent $content "t.Tests.ps1")

            $result | Should -HaveCount 1
        }

        It "recognises any push/pop*Environment pair, not just the testCb helper" {
            $content = '$saved = pushMyEnvironment' + [Environment]::NewLine +
                       'try { $env:FOO = "x" } finally { popMyEnvironment $saved }'
            $result = @(Find-TestAntiPatternsInContent $content "t.Tests.ps1")

            $result | Should -HaveCount 0
        }

        It "flags env var written before the push" {
            $nl = [Environment]::NewLine
            $content = ($script:ep + 'FOO = "x"') + $nl +
                       '$prev = pushTestEnvironment' + $nl +
                       'try { } finally { popTestEnvironment $prev }'
            $result = @(Find-TestAntiPatternsInContent $content "t.Tests.ps1")

            $result | Should -HaveCount 1
            $result[0] | Should -Match 'FOO'
        }

        It "flags env var written after the pop" {
            $nl = [Environment]::NewLine
            $content = '$prev = pushTestEnvironment' + $nl +
                       'try { } finally { popTestEnvironment $prev }' + $nl +
                       ($script:ep + 'FOO = "x"')
            $result = @(Find-TestAntiPatternsInContent $content "t.Tests.ps1")

            $result | Should -HaveCount 1
            $result[0] | Should -Match 'FOO'
        }

        It "does not flag when multiple pairs cover separate writes" {
            $nl = [Environment]::NewLine
            $content = '$p1 = pushTestEnvironment' + $nl +
                       ('try { ' + $script:ep + 'FOO = "x" } finally { popTestEnvironment $p1 }') + $nl +
                       '$p2 = pushTestEnvironment' + $nl +
                       ('try { ' + $script:ep + 'BAR = "y" } finally { popTestEnvironment $p2 }')
            $result = @(Find-TestAntiPatternsInContent $content "t.Tests.ps1")

            $result | Should -HaveCount 0
        }

        It "flags write that falls between two pairs but outside both" {
            $nl = [Environment]::NewLine
            $content = '$p1 = pushTestEnvironment' + $nl +
                       'try { } finally { popTestEnvironment $p1 }' + $nl +
                       ($script:ep + 'FOO = "x"') + $nl +
                       '$p2 = pushTestEnvironment' + $nl +
                       'try { } finally { popTestEnvironment $p2 }'
            $result = @(Find-TestAntiPatternsInContent $content "t.Tests.ps1")

            $result | Should -HaveCount 1
            $result[0] | Should -Match 'FOO'
        }
    }

    Context "# TestAntiPatternOK suppressor" {
        BeforeAll { $script:h = '$' + 'home' }

        It "suppresses env var finding on a line marked OK" {
            $result = @(Find-TestAntiPatternsInContent '$env:PATH = "x"  # TestAntiPatternOK' "t.Tests.ps1")

            $result | Should -HaveCount 0
        }

        It "suppresses home-write finding on a line marked OK" {
            $result = @(Find-TestAntiPatternsInContent ('Set-Content "' + $script:h + '/f" "y"  # TestAntiPatternOK') "t.Tests.ps1")

            $result | Should -HaveCount 0
        }

        It "suppresses only the marked line, leaving other findings intact" {
            $content = ($script:ep + 'PATH = "x"  # TestAntiPatternOK') + [Environment]::NewLine +
                       ($script:ep + 'OTHER = "y"')
            $result = @(Find-TestAntiPatternsInContent $content "t.Tests.ps1")

            $result | Should -HaveCount 1
            $result[0] | Should -Match 'OTHER'
        }
    }
}

Describe "Get-TestAntiPatternFindings" {
    BeforeEach {
        $script:testDir = Join-Path (Resolve-Path "TestDrive:\").ProviderPath "tap-test"
        New-Item $script:testDir -ItemType Directory | Out-Null
    }
    AfterEach {
        Remove-Item $script:testDir -Recurse -Force
    }

    It "finds anti-patterns in a .Tests.ps1 file" {
        ($script:ep + 'FOO = "bar"') | Set-Content "$script:testDir/Bad.Tests.ps1" -Encoding utf8NoBOM

        $result = @(Get-TestAntiPatternFindings -Path $script:testDir)

        $result | Should -Not -BeNullOrEmpty
        $result[0] | Should -Match 'FOO'
    }

    It "ignores non-test .ps1 files" {
        ($script:ep + 'FOO = "bar"') | Set-Content "$script:testDir/Foo.ps1" -Encoding utf8NoBOM

        $result = @(Get-TestAntiPatternFindings -Path $script:testDir)

        $result | Should -HaveCount 0
    }

    It "returns empty for a clean test file" {
        'Write-Host "hello"' | Set-Content "$script:testDir/Clean.Tests.ps1" -Encoding utf8NoBOM

        $result = @(Get-TestAntiPatternFindings -Path $script:testDir)

        $result | Should -HaveCount 0
    }

    It "accepts a single file path directly" {
        $file = "$script:testDir/Single.Tests.ps1"
        ($script:ep + 'BAR = "x"') | Set-Content $file -Encoding utf8NoBOM

        $result = @(Get-TestAntiPatternFindings -Path $file)

        $result | Should -Not -BeNullOrEmpty
        $result[0] | Should -Match 'BAR'
    }
}
