BeforeAll {
    . "$PSScriptRoot/Set-PratBinPaths.ps1"
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
