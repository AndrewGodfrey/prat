BeforeAll {
    . "$PSScriptRoot/Get-GitRepoState.ps1"
}

Describe 'Get-WatchedRepoPaths' {
    Context 'not a git repo' {
        BeforeAll { Mock Invoke-GitOutput { $null } }

        It 'returns empty array' {
            @(Get-WatchedRepoPaths 'C:/notgit') | Should -HaveCount 0
        }
    }

    Context 'git repo without Get-CodebaseLayers.ps1' {
        BeforeAll {
            $repoRoot    = (New-Item -ItemType Directory 'TestDrive:/repo-simple').FullName
            $repoRootFwd = $repoRoot -replace '\\', '/'
            Mock Invoke-GitOutput { $repoRootFwd }
        }

        It 'returns git root (forward-slash path)' {
            Get-WatchedRepoPaths "$repoRoot/subdir" | Should -Be @($repoRootFwd)
        }
    }

    Context 'git repo with Get-CodebaseLayers.ps1' {
        BeforeAll {
            $repoRoot = (New-Item -ItemType Directory 'TestDrive:/repo-layered').FullName
            $null = New-Item -ItemType Directory "$repoRoot/pathbin"
            Set-Content "$repoRoot/pathbin/Get-CodebaseLayers.ps1" @'
return @(
    @{Name='de';    Path='C:/Users/test/de'},
    @{Name='prefs'; Path='C:/Users/test/prefs'},
    @{Name='prat';  Path='C:/Users/test/prat'}
)
'@
            Mock Invoke-GitOutput { $repoRoot }
        }

        It 'returns paths from all codebase layers' {
            Get-WatchedRepoPaths $repoRoot |
                Should -Be @('C:/Users/test/de', 'C:/Users/test/prefs', 'C:/Users/test/prat')
        }
    }
}

Describe 'Parse-StatusFiles' {
    It 'returns empty for empty status' {
        @(Parse-StatusFiles '') | Should -HaveCount 0
        @(Parse-StatusFiles $null) | Should -HaveCount 0
    }
    It 'parses modified and untracked files' {
        $status = " M lib/foo.ps1`n?? newfile.ps1"
        $files = Parse-StatusFiles $status
        $files | Should -Contain 'lib/foo.ps1'
        $files | Should -Contain 'newfile.ps1'
    }
    It 'handles staged rename by returning new path' {
        $files = Parse-StatusFiles 'R  old.ps1 -> new.ps1'
        $files | Should -Be @('new.ps1')
    }
    It 'handles unstaged modification (leading space preserved)' {
        $files = Parse-StatusFiles ' M lib/foo.ps1'
        $files | Should -Be @('lib/foo.ps1')
    }
}

Describe 'Get-SingleRepoState' {
    Context 'basic state capture with no uncommitted files' {
        BeforeAll {
            Mock Invoke-GitOutput {
                switch ($gitArgs[0]) {
                    'branch' { 'main' }
                    'log'    { "abc1234 commit one`ndef5678 commit two`nghi9012 commit three" }
                    'status' { '' }
                }
            }
        }

        It 'returns branch'  { (Get-SingleRepoState 'C:/repo').branch | Should -Be 'main' }
        It 'returns log'     { (Get-SingleRepoState 'C:/repo').log    | Should -Be "abc1234 commit one`ndef5678 commit two`nghi9012 commit three" }
        It 'returns status'  { (Get-SingleRepoState 'C:/repo').status | Should -Be '' }
        It 'returns empty uncommittedHashes' {
            (Get-SingleRepoState 'C:/repo').uncommittedHashes | Should -BeNullOrEmpty
        }
    }

    Context 'few uncommitted files (<=5)' {
        BeforeAll {
            $repoPath = (New-Item -ItemType Directory 'TestDrive:/repo-few').FullName
            Set-Content "$repoPath/file1.txt" 'content1'
            Set-Content "$repoPath/file2.txt" 'content2'

            Mock Invoke-GitOutput {
                switch ($gitArgs[0]) {
                    'branch' { 'main' }
                    'log'    { '' }
                    'status' { " M file1.txt`n?? file2.txt" }
                }
            }
        }

        It 'stores one hash per file' {
            $state = Get-SingleRepoState $repoPath
            $state.uncommittedHashes.Count | Should -Be 2
            $state.uncommittedHashes['file1.txt'] | Should -Not -BeNullOrEmpty
            $state.uncommittedHashes['file2.txt'] | Should -Not -BeNullOrEmpty
        }
        It 'hashes differ for different file content' {
            $state = Get-SingleRepoState $repoPath
            $state.uncommittedHashes['file1.txt'] | Should -Not -Be $state.uncommittedHashes['file2.txt']
        }
        It 'hash changes when file content changes' {
            $hash1 = (Get-SingleRepoState $repoPath).uncommittedHashes['file1.txt']
            Set-Content "$repoPath/file1.txt" 'different content'
            $hash2 = (Get-SingleRepoState $repoPath).uncommittedHashes['file1.txt']
            $hash1 | Should -Not -Be $hash2
        }
    }

    Context 'many uncommitted files (>50)' {
        BeforeAll {
            $repoPath = (New-Item -ItemType Directory 'TestDrive:/repo-many').FullName
            1..51 | ForEach-Object { Set-Content "$repoPath/file$_.txt" "content$_" }

            Mock Invoke-GitOutput {
                switch ($gitArgs[0]) {
                    'branch' { 'main' }
                    'log'    { '' }
                    'status' { (1..51 | ForEach-Object { "?? file$_.txt" }) -join "`n" }
                }
            }
        }

        It 'stores consolidated hash under __all__ key' {
            $state = Get-SingleRepoState $repoPath
            @($state.uncommittedHashes.Keys) | Should -Be @('__all__')
        }
        It 'consolidated hash changes when a file changes' {
            $hash1 = (Get-SingleRepoState $repoPath).uncommittedHashes['__all__']
            Set-Content "$repoPath/file1.txt" 'different'
            $hash2 = (Get-SingleRepoState $repoPath).uncommittedHashes['__all__']
            $hash1 | Should -Not -Be $hash2
        }
    }
}

Describe 'Get-SnapshotPath' {
    It 'produces same hash for forward-slash and backslash cwd' {
        $fwd  = Get-SnapshotPath 'C:/snaps' 'sess1' 'C:/Users/andrew/de'
        $back = Get-SnapshotPath 'C:/snaps' 'sess1' 'C:\Users\andrew\de'
        $fwd | Should -Be $back
    }
    It 'produces same hash regardless of trailing slash' {
        $a = Get-SnapshotPath 'C:/snaps' 'sess1' 'C:/Users/andrew/de'
        $b = Get-SnapshotPath 'C:/snaps' 'sess1' 'C:/Users/andrew/de/'
        $a | Should -Be $b
    }
}

Describe 'Get-GitRepoState' {
    Context 'repoSubdir is not a git repo' {
        BeforeAll { Mock Invoke-GitOutput { $null } }

        It 'returns null' {
            Get-GitRepoState 'C:/notgit' | Should -BeNullOrEmpty
        }
    }

    Context 'single git repo' {
        BeforeAll {
            Mock Get-WatchedRepoPaths { @('C:/repos/foo') }
            Mock Invoke-GitOutput {
                switch ($gitArgs[0]) {
                    'rev-parse' { '.git' }
                    'branch'    { 'main' }
                    'log'       { 'abc1234 commit one' }
                    'status'    { '' }
                }
            }
        }

        It 'returns state keyed by repo path' {
            $state = Get-GitRepoState 'C:/repos/foo'
            $state.Keys | Should -Contain 'C:/repos/foo'
        }
        It 'state contains branch' {
            (Get-GitRepoState 'C:/repos/foo')['C:/repos/foo'].branch | Should -Be 'main'
        }
    }
}
