BeforeDiscovery {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}
BeforeAll {
    Import-Module "$PSScriptRoot/PratBase.psd1" -Force
}

Describe "Resolve-GitRoot" {
    BeforeAll {
        $realTestDrive = ((Get-Item "TestDrive:\").FullName -replace '\\', '/').TrimEnd('/')
        $repoDir = "$realTestDrive/repo"
        New-Item -ItemType Directory $repoDir | Out-Null
        git -C $repoDir init -q
        New-Item "$repoDir/file.txt" | Out-Null
        git -C $repoDir add . 2>$null
        git -C $repoDir -c user.email="t@t" -c user.name="t" commit -q -m "init" 2>$null

        $startDir = "$realTestDrive/start"
        New-Item -ItemType Directory $startDir | Out-Null
        Push-Location $startDir

        # Guard: "not a repo" tests require TestDrive to be outside any git repo.
        # If this fires, the test environment is unusually configured.
        if (git -C $realTestDrive rev-parse --show-toplevel 2>$null) {
            throw "TestDrive ($realTestDrive) is inside a git repo — cannot test the null-return cases"
        }
    }
    AfterAll {
        Pop-Location
    }

    It "Returns repo root for a file path inside a git repo" {
        $result = Resolve-GitRoot "$repoDir/file.txt"
        $result | Should -Be $repoDir
    }

    It "Returns repo root for a directory path inside a git repo" {
        $result = Resolve-GitRoot $repoDir
        $result | Should -Be $repoDir
    }

    It "Returns null/empty for a path not in any git repo" {
        $result = Resolve-GitRoot "$realTestDrive/notarepo"
        $result | Should -BeNullOrEmpty
    }

    It "Returns repo root when no path given and cwd is inside a git repo" {
        Push-Location $repoDir
        try {
            $result = Resolve-GitRoot
            $result | Should -Be $repoDir
        } finally {
            Pop-Location
        }
    }

    It "Returns null/empty when no path given and cwd is not in a git repo" {
        # cwd is $startDir (set in BeforeAll), which is not a git repo
        $result = Resolve-GitRoot
        $result | Should -BeNullOrEmpty
    }

    It "Restores cwd after call with no path (cwd is git repo)" {
        Push-Location $repoDir
        try {
            Resolve-GitRoot | Out-Null
            (Get-Location).Path | Should -Be ($repoDir -replace '/', '\')
        } finally {
            Pop-Location
        }
    }

    It "Expands a leading '~' before resolving (git -C cannot read a literal '~')" {
        # ~ only expands relative to $HOME, so the repo must live under $HOME for this to exercise
        # the tilde path. Created and cleaned up here rather than in TestDrive.
        $tildeRepoName = "resolveGitRootTest_$([guid]::NewGuid().ToString('N'))"
        $realTildeRepo = Join-Path $HOME $tildeRepoName
        try {
            New-Item -ItemType Directory $realTildeRepo | Out-Null
            git -C $realTildeRepo init -q
            New-Item "$realTildeRepo/file.txt" | Out-Null
            git -C $realTildeRepo add . 2>$null
            git -C $realTildeRepo -c user.email="t@t" -c user.name="t" commit -q -m "init" 2>$null

            $result = Resolve-GitRoot "~/$tildeRepoName/file.txt"
            $result | Should -Be (($realTildeRepo -replace '\\', '/').TrimEnd('/'))
        } finally {
            Remove-Item $realTildeRepo -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "Stays in the caller's path space when the path traverses a junction (does not resolve to the real target)" {
        $realRepoDir = "$realTestDrive/realRepo"
        New-Item -ItemType Directory $realRepoDir | Out-Null
        git -C $realRepoDir init -q
        New-Item "$realRepoDir/file.txt" | Out-Null
        git -C $realRepoDir add . 2>$null
        git -C $realRepoDir -c user.email="t@t" -c user.name="t" commit -q -m "init" 2>$null

        $junctionParent = "$realTestDrive/junctionParent"
        New-Item -ItemType Directory $junctionParent | Out-Null
        $junctionPath = "$junctionParent/repoLink"
        New-Item -ItemType Junction -Path $junctionPath -Target $realRepoDir | Out-Null

        $result = Resolve-GitRoot "$junctionPath/file.txt"
        $result | Should -Be $junctionPath
    }
}
