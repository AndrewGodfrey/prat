BeforeAll {
    . "$PSScriptRoot/Set-PratBinPaths.ps1"
}

Describe 'Set-PratBinPaths' {
    BeforeEach {
        $script:savedPath = $env:Path
        $script:cacheFile = Join-Path $TestDrive ([guid]::NewGuid().ToString() + '.json')
        Mock Test-Path { $false } -ParameterFilter { $Path -eq "$home\prat\auto\profile\Get-OverrideBinPaths.ps1" }
        Mock Resolve-Path { [pscustomobject]@{ Path = 'C:\junction\prat\pathbin' } }
        Mock Resolve-JunctionInPath {
            param($path)
            if ($path -ieq 'C:\junction\prat\pathbin') { return 'C:\real\prat\pathbin' }
            return $path
        }
    }
    AfterEach {
        $env:Path = $script:savedPath
    }

    It 'preserves ordering and removes empty entries and junction equivalents' {
        $env:Path = 'C:\first\bin;;C:\REAL\prat\pathbin;C:\last\bin;C:\first\bin'

        Set-PratBinPaths -CacheFile $script:cacheFile

        $env:Path | Should -Be "C:\first\bin;C:\last\bin;C:\first\bin;C:\junction\prat\pathbin;$home\prat\auto\pathbin"
    }

    It 'resolves each distinct PATH entry only once across additions' {
        $env:Path = 'C:\first\bin;C:\FIRST\bin;C:\last\bin'

        Set-PratBinPaths -CacheFile $script:cacheFile

        $env:Path | Should -Be "C:\first\bin;C:\FIRST\bin;C:\last\bin;C:\junction\prat\pathbin;$home\prat\auto\pathbin"
        Should -Invoke Resolve-JunctionInPath -Exactly -Times 1 -ParameterFilter { $path -ieq 'C:\first\bin' }
        Should -Invoke Resolve-JunctionInPath -Exactly -Times 1 -ParameterFilter { $path -ieq 'C:\last\bin' }
        Should -Invoke Resolve-JunctionInPath -Exactly -Times 1 -ParameterFilter { $path -ieq 'C:\junction\prat\pathbin' }
    }

    It 'refreshes junction resolutions when the input PATH changes' {
        $env:Path = 'C:\first\bin'
        Set-PratBinPaths -CacheFile $script:cacheFile
        Mock Resolve-JunctionInPath {
            param($path)
            if ($path -ieq 'C:\first\bin') { return 'C:\real\prat\pathbin' }
            if ($path -ieq 'C:\junction\prat\pathbin') { return 'C:\real\prat\pathbin' }
            return $path
        }

        Set-PratBinPaths -CacheFile $script:cacheFile

        $env:Path | Should -Be "C:\junction\prat\pathbin;$home\prat\auto\pathbin"
    }

    It 'reuses the cached result for the exact same input PATH without resolving junctions' {
        $inputPath = 'C:\first\bin;;C:\REAL\prat\pathbin;C:\last\bin'
        $env:Path = $inputPath
        Set-PratBinPaths -CacheFile $script:cacheFile
        $expectedPath = $env:Path
        Mock Resolve-JunctionInPath { throw 'Cache hit must not resolve junctions' }
        $env:Path = $inputPath

        Set-PratBinPaths -CacheFile $script:cacheFile

        $env:Path | Should -Be $expectedPath
        Should -Invoke Resolve-JunctionInPath -Exactly -Times 1 -ParameterFilter { $path -eq 'C:\first\bin' }
    }

    It 'invalidates the cache when the input PATH changes only in case' {
        $env:Path = 'C:\first\bin'
        Set-PratBinPaths -CacheFile $script:cacheFile
        $env:Path = 'C:\FIRST\bin'

        Set-PratBinPaths -CacheFile $script:cacheFile

        $env:Path | Should -BeExactly "C:\FIRST\bin;C:\junction\prat\pathbin;$home\prat\auto\pathbin"
        Should -Invoke Resolve-JunctionInPath -Exactly -Times 2 -ParameterFilter { $path -ieq 'C:\first\bin' }
    }

    It 'invalidates the cache when the configured directories change' {
        $env:Path = 'C:\first\bin'
        Set-PratBinPaths -CacheFile $script:cacheFile
        Mock Resolve-Path { [pscustomobject]@{ Path = 'C:\other\prat\pathbin' } }
        $env:Path = 'C:\first\bin'

        Set-PratBinPaths -CacheFile $script:cacheFile

        $env:Path | Should -Be "C:\first\bin;C:\other\prat\pathbin;$home\prat\auto\pathbin"
        Should -Invoke Resolve-JunctionInPath -Exactly -Times 1 -ParameterFilter { $path -eq 'C:\other\prat\pathbin' }
    }

    It 'expires the cache after one week' {
        $env:Path = 'C:\first\bin'
        Set-PratBinPaths -CacheFile $script:cacheFile
        $cache = Get-Content -LiteralPath $script:cacheFile -Raw | ConvertFrom-Json
        $cache.Entries[0].CreatedUtc = [datetime]::UtcNow.AddDays(-7).AddMinutes(-1).ToString('o')
        $cache | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:cacheFile
        $env:Path = 'C:\first\bin'

        Set-PratBinPaths -CacheFile $script:cacheFile

        Should -Invoke Resolve-JunctionInPath -Exactly -Times 2 -ParameterFilter { $path -eq 'C:\first\bin' }
        $updated = Get-Content -LiteralPath $script:cacheFile -Raw | ConvertFrom-Json
        ([datetime]$updated.Entries[0].CreatedUtc) | Should -BeGreaterThan ([datetime]::UtcNow.AddMinutes(-1))
    }

    It 'does not extend the expiration time on a cache hit' {
        $env:Path = 'C:\first\bin'
        Set-PratBinPaths -CacheFile $script:cacheFile
        $cache = Get-Content -LiteralPath $script:cacheFile -Raw | ConvertFrom-Json
        $cache.Entries[0].CreatedUtc = [datetime]::UtcNow.AddDays(-6).ToString('o')
        $cache | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:cacheFile
        $before = Get-Content -LiteralPath $script:cacheFile -Raw
        $env:Path = 'C:\first\bin'

        Set-PratBinPaths -CacheFile $script:cacheFile

        (Get-Content -LiteralPath $script:cacheFile -Raw) | Should -BeExactly $before
    }

    It 'retains both results when startup PATH strings alternate' {
        $env:Path = 'C:\first\bin'
        Set-PratBinPaths -CacheFile $script:cacheFile
        $firstResult = $env:Path
        $env:Path = 'C:\second\bin'
        Set-PratBinPaths -CacheFile $script:cacheFile
        $secondResult = $env:Path
        Mock Resolve-JunctionInPath { throw 'Alternating cache hits must not resolve junctions' }

        $env:Path = 'C:\first\bin'
        Set-PratBinPaths -CacheFile $script:cacheFile
        $env:Path | Should -Be $firstResult
        $env:Path = 'C:\second\bin'
        Set-PratBinPaths -CacheFile $script:cacheFile
        $env:Path | Should -Be $secondResult
    }

    It 'keeps at most four startup configurations and evicts the oldest' {
        foreach ($index in 1..5) {
            $env:Path = "C:\input$index\bin"
            Set-PratBinPaths -CacheFile $script:cacheFile
        }
        $cache = Get-Content -LiteralPath $script:cacheFile -Raw | ConvertFrom-Json
        @($cache.Entries) | Should -HaveCount 4
        @($cache.Entries.InputPath) | Should -Not -Contain 'C:\input1\bin'
        $env:Path = 'C:\input1\bin'

        Set-PratBinPaths -CacheFile $script:cacheFile

        Should -Invoke Resolve-JunctionInPath -Exactly -Times 2 -ParameterFilter { $path -eq 'C:\input1\bin' }
    }
}

Describe 'addJunctionPath' {
    BeforeEach {
        $script:savedPath = $env:Path
    }
    AfterEach {
        $env:Path = $script:savedPath
    }

    Context 'when PATH has a real-path equivalent of the junction path' {
        BeforeAll {
            # Simulate: C:\junction\de\pathbin and C:\real\de\pathbin both resolve to C:\real\de\pathbin.
            # Everything else resolves to itself.
            function Resolve-JunctionInPath($path) {
                if ($path -ieq 'C:\junction\de\pathbin' -or $path -ieq 'C:\real\de\pathbin') {
                    return 'C:\real\de\pathbin'
                }
                return $path
            }
        }

        It 'adds the junction path' {
            $env:Path = 'C:\unrelated\bin'
            addJunctionPath 'C:\junction\de\pathbin'
            ($env:Path -split ';') | Should -Contain 'C:\junction\de\pathbin'
        }

        It 'removes the real-path equivalent' {
            $env:Path = 'C:\real\de\pathbin;C:\unrelated\bin'
            addJunctionPath 'C:\junction\de\pathbin'
            ($env:Path -split ';') | Should -Not -Contain 'C:\real\de\pathbin'
        }

        It 'preserves unrelated PATH entries' {
            $env:Path = 'C:\unrelated\bin;C:\real\de\pathbin'
            addJunctionPath 'C:\junction\de\pathbin'
            ($env:Path -split ';') | Should -Contain 'C:\unrelated\bin'
        }

        It 'is idempotent — second call does not duplicate the junction path' {
            $env:Path = 'C:\unrelated\bin'
            addJunctionPath 'C:\junction\de\pathbin'
            addJunctionPath 'C:\junction\de\pathbin'
            $count = @(($env:Path -split ';') | Where-Object { $_ -ieq 'C:\junction\de\pathbin' }).Count
            $count | Should -Be 1
        }
    }

    Context 'when PATH has no real-path equivalent' {
        BeforeAll {
            function Resolve-JunctionInPath($path) { return $path }
        }

        It 'appends the path without removing anything' {
            $env:Path = 'C:\unrelated\bin'
            addJunctionPath 'C:\new\bin'
            ($env:Path -split ';') | Should -Contain 'C:\unrelated\bin'
            ($env:Path -split ';') | Should -Contain 'C:\new\bin'
        }
    }
}
