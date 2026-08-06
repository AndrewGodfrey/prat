BeforeAll {
    . "$PSScriptRoot/Define-ShortcutFunctions.ps1"
    # The function is only reachable because interactiveProfile_prat.ps1 deletes the built-in
    # `ls` alias (aliases outrank functions); mirror that here.
    if (Test-Path alias:ls) { Remove-Item alias:ls }
}

Describe "ls" {
    BeforeAll {
        New-Item -ItemType File "TestDrive:/a.txt" | Out-Null
        New-Item -ItemType File "TestDrive:/b.txt" | Out-Null
    }

    It "emits raw FileSystemInfo objects when piped, so property access works" {
        $names = ls TestDrive:/ | ForEach-Object Name

        $names | Should -Contain 'a.txt'
        $names | Should -Contain 'b.txt'
    }

    It "formats wide when it is the last pipeline element" {
        $out = ls TestDrive:/

        $out[0].GetType().FullName | Should -BeLike 'Microsoft.PowerShell.Commands.Internal.Format.*'
    }
}
