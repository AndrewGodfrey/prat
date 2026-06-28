BeforeAll {
    . $PSScriptRoot/../Find-LayerViolations.ps1

    # Assembled to avoid literal banned strings appearing in this source file
    $script:dePattern    = "~/" + "de/"
    $script:prefsPattern = "~/" + "prefs/"

    # Simulates patterns a de config would inject (private to de, assembled here for same reason)
    $script:getDiffCovPat = "Get-Diff" + "Coverage"
    $script:workPathPat   = "/q" + "/src/"

    $script:testConfig = @{
        bannedPatterns = @(
            @{ pattern = $script:dePattern;    description = "$($script:dePattern) reference" },
            @{ pattern = $script:prefsPattern; description = "$($script:prefsPattern) reference" }
        )
    }

    $script:augmentedConfig = @{
        bannedPatterns = @(
            @{ pattern = $script:dePattern;       description = "$($script:dePattern) reference" },
            @{ pattern = $script:prefsPattern;    description = "$($script:prefsPattern) reference" },
            @{ pattern = $script:getDiffCovPat;   description = "$($script:getDiffCovPat) (private work-de function)" },
            @{ pattern = $script:workPathPat;     description = "$($script:workPathPat) (work-specific path)" }
        )
    }
}

Describe "Find-LayerViolationsInContent" {
    Context "clean content" {
        It "returns no findings for clean content" {
            $result = @(Find-LayerViolationsInContent -Content "hello world" -RelPath "foo.ps1" -Config $script:testConfig)

            $result | Should -HaveCount 0
        }

        It "does not flag ~/prat/ paths" {
            $result = @(Find-LayerViolationsInContent -Content "t ~/prat/lib/Something -NoCoverage" -RelPath "SKILL.md" -Config $script:testConfig)

            $result | Should -HaveCount 0
        }
    }

    Context "de-layer reference" {
        It "flags a de-layer path reference in content" {
            $result = @(Find-LayerViolationsInContent -Content "see $($script:dePattern)lib/foo.ps1" -RelPath "README.md" -Config $script:testConfig)

            $result | Should -HaveCount 1
            $result[0] | Should -Match $script:dePattern
        }

        It "includes line number in the finding" {
            $content = "clean line" + [Environment]::NewLine + "see $($script:dePattern)lib/foo.ps1"
            $result = @(Find-LayerViolationsInContent -Content $content -RelPath "foo.md" -Config $script:testConfig)

            $result[0] | Should -Match 'line 2'
        }

        It "includes the relative file path in the finding" {
            $result = @(Find-LayerViolationsInContent -Content "see $($script:dePattern)lib/foo.ps1" -RelPath "lib/agents/SKILL.md" -Config $script:testConfig)

            $result[0] | Should -Match 'lib/agents/SKILL\.md'
        }

        It "collects all line numbers when the pattern appears on multiple lines" {
            $nl = [Environment]::NewLine
            $hit = "see $($script:dePattern)foo"
            $content = $hit + $nl + "clean" + $nl + $hit
            $result = @(Find-LayerViolationsInContent -Content $content -RelPath "foo.md" -Config $script:testConfig)

            $result[0] | Should -Match 'line 1, 3'
        }
    }

    Context "prefs-layer reference" {
        It "flags a prefs-layer path reference in content" {
            $result = @(Find-LayerViolationsInContent -Content "copy to $($script:prefsPattern)pathbin" -RelPath "foo.md" -Config $script:testConfig)

            $result | Should -HaveCount 1
            $result[0] | Should -Match $script:prefsPattern
        }
    }

    Context "violations from pending-layer-violations branch (simulating de augmentation)" {
        It "flags Get-DiffCoverage reference when in config" {
            # Mirrors: Test-Codebase.ps1 comment added in pending-layer-violations branch
            $content = "Compatible directly with $($script:getDiffCovPat).ps1 — no"
            $result = @(Find-LayerViolationsInContent -Content $content -RelPath "pathbin/Test-Codebase.ps1" -Config $script:augmentedConfig)

            $result | Should -HaveCount 1
            $result[0] | Should -Match $script:getDiffCovPat
        }

        It "flags /q/src/ work path when in config" {
            # Mirrors: prat-run-tests/SKILL.md example added in pending-layer-violations branch
            $content = "t $($script:workPathPat)CloudTest/private/Services/Foo/UnitTests   # .NET"
            $result = @(Find-LayerViolationsInContent -Content $content -RelPath "lib/agents/skills/prat-run-tests/SKILL.md" -Config $script:augmentedConfig)

            $result | Should -HaveCount 1
            $result[0] | Should -Match ([regex]::Escape($script:workPathPat))
        }
    }

    Context "multiple violations" {
        It "returns one finding per violated rule" {
            $content = "ref $($script:dePattern)foo and $($script:prefsPattern)bar"
            $result = @(Find-LayerViolationsInContent -Content $content -RelPath "foo.md" -Config $script:testConfig)

            $result | Should -HaveCount 2
        }

        It "returns only one finding per rule even when the pattern appears multiple times" {
            $content = "see $($script:dePattern)a and $($script:dePattern)b"
            $result = @(Find-LayerViolationsInContent -Content $content -RelPath "foo.md" -Config $script:testConfig)

            $result | Should -HaveCount 1
        }
    }
}

Describe "Get-LayerViolationFindings" {
    BeforeAll {
        $script:realTestDrive = ((Get-Item "TestDrive:\").FullName -replace '\\', '/').TrimEnd('/')

        $script:dirConfig = @{
            bannedPatterns = @(
                @{ pattern = $script:dePattern; description = "$($script:dePattern) reference" }
            )
        }
    }

    Context "directory scanning" {
        BeforeEach {
            $script:testDir = "$script:realTestDrive/flv-$([System.IO.Path]::GetRandomFileName())"
            New-Item -ItemType Directory -Path $script:testDir | Out-Null
        }
        AfterEach {
            Remove-Item $script:testDir -Recurse -Force
        }

        It "finds violations in a .ps1 file" {
            "see $($script:dePattern)lib/foo.ps1" | Set-Content "$script:testDir/script.ps1" -Encoding utf8NoBOM

            $result = @(Get-LayerViolationFindings -Path $script:testDir -Config $script:dirConfig)

            $result | Should -HaveCount 1
            $result[0] | Should -Match $script:dePattern
        }

        It "finds violations in a .md file" {
            "see $($script:dePattern)lib/foo.ps1" | Set-Content "$script:testDir/README.md" -Encoding utf8NoBOM

            $result = @(Get-LayerViolationFindings -Path $script:testDir -Config $script:dirConfig)

            $result | Should -HaveCount 1
        }

        It "finds violations in a .py file" {
            "_mcp = FastMCP('$($script:dePattern)sandbox')" | Set-Content "$script:testDir/server.py" -Encoding utf8NoBOM

            $result = @(Get-LayerViolationFindings -Path $script:testDir -Config $script:dirConfig)

            $result | Should -HaveCount 1
        }

        It "scans .txt files" {
            "see $($script:dePattern)lib/foo.ps1" | Set-Content "$script:testDir/notes.txt" -Encoding utf8NoBOM

            $result = @(Get-LayerViolationFindings -Path $script:testDir -Config $script:dirConfig)

            $result | Should -HaveCount 1
        }

        It "ignores non-text files" {
            "see $($script:dePattern)lib/foo.ps1" | Set-Content "$script:testDir/data.bin" -Encoding utf8NoBOM

            $result = @(Get-LayerViolationFindings -Path $script:testDir -Config $script:dirConfig)

            $result | Should -HaveCount 0
        }

        It "returns empty for a clean directory" {
            "hello world" | Set-Content "$script:testDir/clean.ps1" -Encoding utf8NoBOM

            $result = @(Get-LayerViolationFindings -Path $script:testDir -Config $script:dirConfig)

            $result | Should -HaveCount 0
        }

        It "skips files under an excluded path" {
            New-Item -ItemType Directory -Path "$script:testDir/auto" | Out-Null
            "see $($script:dePattern)lib/foo.ps1" | Set-Content "$script:testDir/auto/generated.ps1" -Encoding utf8NoBOM

            $config = @{
                bannedPatterns = @(@{ pattern = $script:dePattern; description = "$($script:dePattern) reference" })
                excludedPaths  = @('auto/')
            }

            $result = @(Get-LayerViolationFindings -Path $script:testDir -Config $config)

            $result | Should -HaveCount 0
        }

        It "still finds violations outside excluded paths" {
            New-Item -ItemType Directory -Path "$script:testDir/auto" | Out-Null
            "see $($script:dePattern)lib/foo.ps1" | Set-Content "$script:testDir/auto/generated.ps1" -Encoding utf8NoBOM
            "see $($script:dePattern)lib/foo.ps1" | Set-Content "$script:testDir/normal.ps1" -Encoding utf8NoBOM

            $config = @{
                bannedPatterns = @(@{ pattern = $script:dePattern; description = "$($script:dePattern) reference" })
                excludedPaths  = @('auto/')
            }

            $result = @(Get-LayerViolationFindings -Path $script:testDir -Config $config)

            $result | Should -HaveCount 1
            $result[0] | Should -Match 'normal\.ps1'
        }
    }
}
