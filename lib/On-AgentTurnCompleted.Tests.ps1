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
