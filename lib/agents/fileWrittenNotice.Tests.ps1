BeforeAll {
    . "$PSScriptRoot/fileWrittenNotice.ps1"
    # TestDrive: is a PowerShell provider path, which .NET file APIs and external tools reject.
    $script:testRoot = ((Get-Item "TestDrive:\").FullName -replace '\\', '/').TrimEnd('/')
}

Describe "Send-FileWrittenNotice" {
    BeforeAll {
        function New-Companion([string] $name, [string] $body) {
            $path = "$testRoot/$name"
            Set-Content -LiteralPath $path "param([string] `$Path)`n$body"
            return $path
        }
        $script:log = "$testRoot/log.txt"
    }
    BeforeEach {
        Remove-Item -LiteralPath $log -ErrorAction Ignore
    }

    It "runs each companion with the path" {
        $a = New-Companion "a.ps1" "Add-Content -LiteralPath '$log' ""a `$Path"""
        $b = New-Companion "b.ps1" "Add-Content -LiteralPath '$log' ""b `$Path"""

        Send-FileWrittenNotice -Path "C:/x/plan.md" -CompanionPaths @($a, $b)

        Get-Content -LiteralPath $log | Should -Be @("a C:/x/plan.md", "b C:/x/plan.md")
    }

    It "reports a failing companion without stopping, and still runs the rest" {
        $bad = New-Companion "bad.ps1" "throw 'companion broke'"
        $good = New-Companion "good.ps1" "Add-Content -LiteralPath '$log' ""good `$Path"""

        Send-FileWrittenNotice -Path "C:/x/plan.md" -CompanionPaths @($bad, $good) -ErrorVariable errs -ErrorAction SilentlyContinue

        Get-Content -LiteralPath $log | Should -Be "good C:/x/plan.md"
        "$errs" | Should -BeLike "*bad.ps1*C:/x/plan.md*companion broke*"
    }

    It "looks the companions up by layer when none are given" {
        $script:layered = New-Companion "layered.ps1" "Add-Content -LiteralPath '$log' ""layered `$Path"""
        # A function rather than a Mock: a Pester Mock of this script on PATH (Resolve-PratLibFile.ps1) left the call
        # unintercepted (2026-10), while a function outranks a script in command lookup.
        function Resolve-PratLibFile($file, [switch] $ListAll) { if ($file -eq 'lib/agents/On-FileWritten.ps1' -and $ListAll) { @($script:layered) } }

        Send-FileWrittenNotice -Path "C:/x/plan.md"

        Get-Content -LiteralPath $log | Should -Be "layered C:/x/plan.md"
    }
}
