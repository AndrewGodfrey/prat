BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')

    function makeTranscript([string] $path, [object[]] $entries) {
        $entries | ForEach-Object { $_ | ConvertTo-Json -Compress } | Set-Content $path -Encoding utf8NoBOM
    }
}

Describe "Get-SessionName" {
    BeforeEach {
        $script:dir = Join-Path (Resolve-Path "TestDrive:\").ProviderPath "On-AgentTurnCompleted.Tests"
        mkdir $dir | Out-Null
    }
    AfterEach {
        Remove-Item $dir -Recurse -Force
    }

    It "returns null when transcript_path is absent" {
        Get-SessionName @{} | Should -BeNullOrEmpty
    }

    It "returns null when transcript file does not exist" {
        Get-SessionName @{transcript_path = "$dir/nonexistent.jsonl"} | Should -BeNullOrEmpty
    }

    It "returns slug when no custom-title entry" {
        $f = "$dir/session.jsonl"
        makeTranscript $f @(
            @{type = "user"; slug = "my-slug"; sessionId = "abc"}
        )

        Get-SessionName @{transcript_path = $f} | Should -Be "my-slug"
    }

    It "returns customTitle when custom-title entry is present" {
        $f = "$dir/session.jsonl"
        makeTranscript $f @(
            @{type = "user";         slug = "my-slug";  sessionId = "abc"}
            @{type = "custom-title"; customTitle = "my-name"; sessionId = "abc"}
        )

        Get-SessionName @{transcript_path = $f} | Should -Be "my-name"
    }

    It "prefers customTitle over slug" {
        $f = "$dir/session.jsonl"
        makeTranscript $f @(
            @{type = "user";         slug = "auto-slug"; sessionId = "abc"}
            @{type = "custom-title"; customTitle = "renamed"; sessionId = "abc"}
            @{type = "user";         slug = "auto-slug"; sessionId = "abc"}
        )

        Get-SessionName @{transcript_path = $f} | Should -Be "renamed"
    }

    It "returns the last customTitle when renamed more than once" {
        $f = "$dir/session.jsonl"
        makeTranscript $f @(
            @{type = "custom-title"; customTitle = "first-name";  sessionId = "abc"}
            @{type = "custom-title"; customTitle = "second-name"; sessionId = "abc"}
        )

        Get-SessionName @{transcript_path = $f} | Should -Be "second-name"
    }

    It "returns null when transcript is empty" {
        $f = "$dir/session.jsonl"
        Set-Content $f "" -Encoding utf8NoBOM

        Get-SessionName @{transcript_path = $f} | Should -BeNullOrEmpty
    }
}

Describe 'Save-GitStateSnapshot' {
    Context 'skips when hook data is incomplete' {
        BeforeEach {
            Mock Get-GitCwdState { @{'C:/repo' = @{branch='main'; log=''; status=''; uncommittedHashes=@{}}} }
        }

        It 'skips when session_id is empty' {
            $dir = (New-Item -ItemType Directory 'TestDrive:/snap-skip1').FullName
            Save-GitStateSnapshot @{session_id=''; cwd='C:/repo'} $dir
            (Get-ChildItem $dir).Count | Should -Be 0
        }
        It 'skips when cwd is empty' {
            $dir = (New-Item -ItemType Directory 'TestDrive:/snap-skip2').FullName
            Save-GitStateSnapshot @{session_id='sess123'; cwd=''} $dir
            (Get-ChildItem $dir).Count | Should -Be 0
        }
    }

    Context 'skips when cwd is not a git repo' {
        BeforeEach { Mock Get-GitCwdState { $null } }

        It 'skips when Get-GitCwdState returns null' {
            $dir = (New-Item -ItemType Directory 'TestDrive:/snap-skip3').FullName
            Save-GitStateSnapshot @{session_id='sess123'; cwd='C:/notgit'} $dir
            (Get-ChildItem $dir).Count | Should -Be 0
        }
    }

    Context 'writes snapshot for valid git state' {
        BeforeEach {
            Mock Get-GitCwdState { @{'C:/repo' = @{branch='feature'; log='abc commit'; status='M foo.ps1'; uncommittedHashes=@{}}} }
        }

        It 'creates file named with session_id prefix' {
            $dir = (New-Item -ItemType Directory 'TestDrive:/snap-write1').FullName
            Save-GitStateSnapshot @{session_id='sess123'; cwd='C:/repo'} $dir
            $files = Get-ChildItem $dir
            $files | Should -HaveCount 1
            $files[0].Name | Should -BeLike 'sess123_*.json'
        }
        It 'file contains correct git state' {
            $dir = (New-Item -ItemType Directory 'TestDrive:/snap-write2').FullName
            Save-GitStateSnapshot @{session_id='sess456'; cwd='C:/repo'} $dir
            $file    = Get-ChildItem $dir | Select-Object -First 1
            $content = Get-Content $file.FullName -Raw | ConvertFrom-Json -AsHashtable
            $content['C:/repo'].branch | Should -Be 'feature'
            $content['C:/repo'].status | Should -Be 'M foo.ps1'
        }
    }
}
