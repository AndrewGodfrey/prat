BeforeDiscovery {
    . "$PSScriptRoot/On-UserPromptSubmit.ps1"
}

BeforeAll {
    . "$PSScriptRoot/On-UserPromptSubmit.ps1"
}

Describe 'Get-RepoDiff' {
    BeforeAll {
        $script:base = @{
            branch            = 'main'
            log               = "abc1234 commit one`ndef5678 commit two`nghi9012 commit three"
            status            = ''
            uncommittedHashes = @{}
        }
    }

    It 'returns null when state is identical' {
        Get-RepoDiff $base ($base.Clone()) | Should -BeNullOrEmpty
    }
    It 'detects branch change and includes log' {
        $new = $base.Clone(); $new.branch = 'feature'
        $diff = Get-RepoDiff $base $new
        $diff | Should -Not -BeNullOrEmpty
        $diff.branchOld | Should -Be 'main'
        $diff.branchNew | Should -Be 'feature'
        $diff.ContainsKey('logNew') | Should -BeTrue
    }
    It 'detects log change without branch change' {
        $new = $base.Clone(); $new.log = "newcommit step 4`nabc1234 commit one`ndef5678 commit two"
        $diff = Get-RepoDiff $base $new
        $diff.ContainsKey('logNew') | Should -BeTrue
        $diff.ContainsKey('branchOld') | Should -BeFalse
    }
    It 'detects status change' {
        $new = $base.Clone(); $new.status = ' M lib/foo.ps1'
        (Get-RepoDiff $base $new).statusDelta | Should -Be @(' M lib/foo.ps1')
    }
    It 'identifies changed file by name when per-file hashes available' {
        $old = @{branch='main'; log=''; status=' M lib/foo.ps1'; uncommittedHashes=@{'lib/foo.ps1'='OLDHASH'}}
        $new = @{branch='main'; log=''; status=' M lib/foo.ps1'; uncommittedHashes=@{'lib/foo.ps1'='NEWHASH'}}
        $diff = Get-RepoDiff $old $new
        $diff.uncommittedChangedFiles | Should -Be @('lib/foo.ps1')
        $diff.ContainsKey('uncommittedChanged') | Should -BeFalse
        $diff.ContainsKey('statusDelta') | Should -BeFalse
    }
    It 'uses generic message when consolidated hash used' {
        $old = @{branch='main'; log=''; status=''; uncommittedHashes=@{'__all__'='OLDHASH'}}
        $new = @{branch='main'; log=''; status=''; uncommittedHashes=@{'__all__'='NEWHASH'}}
        $diff = Get-RepoDiff $old $new
        $diff.uncommittedChanged | Should -BeTrue
        $diff.ContainsKey('uncommittedChangedFiles') | Should -BeFalse
    }
    It 'does not set uncommittedChanged when status also changed' {
        $old = @{branch='main'; log=''; status='';               uncommittedHashes=@{}}
        $new = @{branch='main'; log=''; status='?? newfile.ps1'; uncommittedHashes=@{'newfile.ps1'='HASH'}}
        $diff = Get-RepoDiff $old $new
        $diff.statusDelta | Should -Be @('?? newfile.ps1')
        $diff.ContainsKey('uncommittedChanged') | Should -BeFalse
        $diff.ContainsKey('uncommittedChangedFiles') | Should -BeFalse
    }
    It 'detects multiple changes' {
        $new = $base.Clone(); $new.branch = 'feature'; $new.status = ' M lib/foo.ps1'
        $diff = Get-RepoDiff $base $new
        $diff.ContainsKey('branchOld') | Should -BeTrue
        $diff.statusDelta | Should -Be @(' M lib/foo.ps1')
    }
}

Describe 'Format-GitStateMessage' {
    It 'includes header line' {
        $diffs = [ordered]@{'C:/foo' = @{statusDelta=@(' M lib/foo.ps1')}}
        Format-GitStateMessage $diffs $false | Should -BeLike '*git state changed since last turn*'
    }
    It 'formats branch change with commits' {
        $diffs = [ordered]@{'C:/foo' = @{branchOld='main'; branchNew='feature'; logNew="abc1234 step 1`ndef5678 step 2"}}
        $msg = Format-GitStateMessage $diffs $false
        $msg | Should -BeLike '*Branch: main → feature*'
        $msg | Should -BeLike '*abc1234 step 1*'
    }
    It 'formats status change with human-readable labels' {
        $diffs = [ordered]@{'C:/foo' = @{statusDelta=@(' M lib/foo.ps1', '?? newfile.ps1')}}
        $msg = Format-GitStateMessage $diffs $false
        $msg | Should -BeLike '*Status:*'
        $msg | Should -BeLike '*  modified: lib/foo.ps1*'
        $msg | Should -BeLike '*  untracked: newfile.ps1*'
    }
    It 'formats uncommitted content change (generic)' {
        $diffs = [ordered]@{'C:/foo' = @{uncommittedChanged=$true}}
        Format-GitStateMessage $diffs $false | Should -BeLike '*Uncommitted file content changed*'
    }
    It 'formats uncommitted content change with named files' {
        $diffs = [ordered]@{'C:/foo' = @{uncommittedChangedFiles=@('lib/foo.ps1', 'lib/bar.ps1')}}
        $msg = Format-GitStateMessage $diffs $false
        $msg | Should -BeLike '*Content changed:*'
        $msg | Should -BeLike '*  lib/foo.ps1*'
    }
    It 'summarises count when more than 5 files changed' {
        $diffs = [ordered]@{'C:/foo' = @{uncommittedChangedFiles=@('a','b','c','d','e','f')}}
        $msg = Format-GitStateMessage $diffs $false
        $msg | Should -BeLike '*Content changed: 6 files*'
        $msg | Should -Not -BeLike '*  a*'
    }
    It 'omits repo name when showRepoNames is false' {
        $diffs = [ordered]@{'C:/repos/myrepo' = @{statusDelta=@(' M lib/foo.ps1')}}
        Format-GitStateMessage $diffs $false | Should -Not -Match '\[myrepo\]'
    }
    It 'includes repo name when showRepoNames is true' {
        $diffs = [ordered]@{'C:/repos/de' = @{branchOld='main'; branchNew='feature'; logNew='abc step'}}
        Format-GitStateMessage $diffs $true | Should -BeLike '*[de]*'
    }
    It 'includes names for each changed repo in multi-repo output' {
        $diffs = [ordered]@{
            'C:/repos/de'    = @{branchOld='main'; branchNew='feature'; logNew='abc step'}
            'C:/repos/prefs' = @{statusNew='M lib/foo.ps1'}
        }
        $msg = Format-GitStateMessage $diffs $true
        $msg | Should -BeLike '*[de]*'
        $msg | Should -BeLike '*[prefs]*'
    }
}

Describe 'Format-StatusLine' {
    It 'formats staged modification' { Format-StatusLine 'M  lib/foo.ps1'  | Should -Be 'staged: lib/foo.ps1' }
    It 'formats unstaged modification' { Format-StatusLine ' M lib/foo.ps1' | Should -Be 'modified: lib/foo.ps1' }
    It 'formats untracked file'        { Format-StatusLine '?? newfile.ps1' | Should -Be 'untracked: newfile.ps1' }
    It 'formats added file'            { Format-StatusLine 'A  newfile.ps1' | Should -Be 'added: newfile.ps1' }
    It 'formats rename'                { Format-StatusLine 'R  old.ps1 -> new.ps1' | Should -Be 'renamed: old.ps1 -> new.ps1' }
    It 'falls back to trimmed XY for unknown codes' { Format-StatusLine 'XY file.ps1' | Should -Be 'XY: file.ps1' }
}

Describe 'Get-StatusDelta' {
    It 'returns empty when nothing changed' {
        Get-StatusDelta ' M lib/foo.ps1' ' M lib/foo.ps1' | Should -HaveCount 0
    }
    It 'returns new file' {
        $delta = Get-StatusDelta '' '?? newfile.ps1'
        $delta | Should -Be @('?? newfile.ps1')
    }
    It 'returns nothing for file removed from status' {
        Get-StatusDelta ' M lib/foo.ps1' '' | Should -HaveCount 0
    }
    It 'returns line when status code changes' {
        $delta = Get-StatusDelta '?? newfile.ps1' 'A  newfile.ps1'
        $delta | Should -Be @('A  newfile.ps1')
    }
    It 'returns only changed lines when some files unchanged' {
        $old = " M lib/foo.ps1`n M lib/bar.ps1"
        $new = " M lib/foo.ps1`n?? newfile.ps1"
        $delta = Get-StatusDelta $old $new
        $delta | Should -Be @('?? newfile.ps1')
    }
}

Describe 'Invoke-UserPromptSubmitCompanion' {
    It 'does nothing when companion does not exist' {
        { Invoke-UserPromptSubmitCompanion @{session_id='s'; cwd='C:/x'} 'TestDrive:/nonexistent.ps1' } | Should -Not -Throw
    }
    It 'calls companion and passes hookData via stdin' {
        $markerFile = (Join-Path $TestDrive 'companion-ran.txt') -replace '\\', '/'
        $companionScript = (New-Item (Join-Path $TestDrive 'companion.ps1') -ItemType File -Force).FullName
        Set-Content $companionScript "`$h = ([Console]::In.ReadToEnd()) | ConvertFrom-Json; Set-Content '$markerFile' `$h.session_id"
        Invoke-UserPromptSubmitCompanion @{session_id='test-id'; cwd='C:/test'} $companionScript
        Get-Content $markerFile | Should -Be 'test-id'
    }
}

Describe 'Emit-GitStateDiff' {
    BeforeAll {
        $script:emitDir = (New-Item -ItemType Directory 'TestDrive:/emit-snaps').FullName
    }

    It 'emits nothing when no snapshot file exists' {
        Mock Get-GitCwdState { @{'C:/repo' = @{branch='main'; log=''; status=''; uncommittedHashes=@{}}} }
        $dir    = (New-Item -ItemType Directory 'TestDrive:/emit-snaps/no-snap').FullName
        $output = Emit-GitStateDiff @{session_id='s1'; cwd='C:/repo'} $dir
        $output | Should -BeNullOrEmpty
    }

    It 'emits nothing when state is unchanged' {
        $state = @{'C:/repo' = @{branch='main'; log='abc'; status=''; uncommittedHashes=@{}}}
        Mock Get-GitCwdState { $state }
        $dir  = (New-Item -ItemType Directory 'TestDrive:/emit-snaps/unchanged').FullName
        $snap = Get-SnapshotPath $dir 's2' 'C:/repo'
        $state | ConvertTo-Json -Depth 5 | Set-Content $snap
        Emit-GitStateDiff @{session_id='s2'; cwd='C:/repo'} $dir | Should -BeNullOrEmpty
    }

    It 'emits plain text when state changed' {
        $old = @{'C:/repo' = @{branch='main';    log='abc'; status=''; uncommittedHashes=@{}}}
        $new = @{'C:/repo' = @{branch='feature'; log='abc'; status=''; uncommittedHashes=@{}}}
        Mock Get-GitCwdState { $new }
        $dir  = (New-Item -ItemType Directory 'TestDrive:/emit-snaps/changed').FullName
        $snap = Get-SnapshotPath $dir 's3' 'C:/repo'
        $old | ConvertTo-Json -Depth 5 | Set-Content $snap
        $output = Emit-GitStateDiff @{session_id='s3'; cwd='C:/repo'} $dir
        $output | Should -BeLike '*Branch: main → feature*'
    }

    It 'updates snapshot after emitting' {
        $old = @{'C:/repo' = @{branch='main';    log='old'; status=''; uncommittedHashes=@{}}}
        $new = @{'C:/repo' = @{branch='feature'; log='new'; status=''; uncommittedHashes=@{}}}
        Mock Get-GitCwdState { $new }
        $dir  = (New-Item -ItemType Directory 'TestDrive:/emit-snaps/update').FullName
        $snap = Get-SnapshotPath $dir 's4' 'C:/repo'
        $old | ConvertTo-Json -Depth 5 | Set-Content $snap
        Emit-GitStateDiff @{session_id='s4'; cwd='C:/repo'} $dir | Out-Null
        $updated = Get-Content $snap -Raw | ConvertFrom-Json -AsHashtable
        $updated['C:/repo'].branch | Should -Be 'feature'
    }
}
